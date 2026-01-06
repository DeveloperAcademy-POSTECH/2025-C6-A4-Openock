//
//  WhistleDetector.swift
//  Openock
//
//  Created by JiJooMaeng on 11/06/25.
//

import Foundation
import AVFoundation
import CoreML
import Accelerate

@available(macOS 15.0, *)
class WhistleDetector {
  
  // MARK: - Properties

  private var model: WhistleClassifier?
  private var modelOutputKey: String?  // 모델 출력 키 (동적으로 결정)
  private let sampleRate: Double = 16000  // 모델 학습 시 사용된 샘플레이트
  private let bufferSize = 16000  // 1초 버퍼

  // 2단계 검증 시스템
  private let stage1Threshold: Float = 0.70  // 1단계: 널널한 기준 (의심 구간 포착)
  private let stage2Threshold: Float = 0.80  // 2단계: 엄격한 기준 (최종 확인)

  // 에너지 임계값
  private let minEnergyThreshold: Float = 0.002  // 최소 에너지 임계값
  private let filteredEnergyThreshold: Float = 0.01  // 필터링된 에너지 임계값

  // 호루라기 주파수 범위
  private let whistleFreqLow: Float = 2000.0  // 2000Hz
  private let whistleFreqHigh: Float = 4500.0  // 4500Hz

  // 연속 감지 방지
  private var lastDetectionTime: Date?
  private let detectionCooldown: TimeInterval = 5.0  // 5초 쿨다운

  // 연속 검증 (여러 프레임 연속으로 감지되어야 함)
  private var consecutiveDetections: Int = 0
  private let requiredConsecutiveDetections: Int = 1  // 즉각적인 반응을 위해 1번만

  // 오디오 링 버퍼 (최근 2초 유지 - 축구 중계용)
  private var audioRingBuffer: [[Float]] = []
  private var ringBufferMaxSize: Int = 20  // 동적으로 계산됨 (목표: 2초)
  private let ringBufferTargetSeconds: Double = 2.0  // 링 버퍼 목표 시간
  private let bufferCallInterval: Int = 10  // AudioPipeline에서 10번에 한 번 호출

  // Thread-safe access to ring buffer
  private let ringBufferQueue = DispatchQueue(label: "com.openock.whistledetector.ringbuffer", qos: .userInteractive)
  
  // MARK: - Initialization
  
  init() {
    loadModel()
  }
  
  private func loadModel() {
    do {
      let config = MLModelConfiguration()
      config.computeUnits = .cpuAndNeuralEngine  // Neural Engine 사용

      model = try WhistleClassifier(configuration: config)

      // 모델 출력 키 자동 추출
      if let outputName = model?.model.modelDescription.outputDescriptionsByName.keys.first {
        modelOutputKey = outputName
        print("✅ [WhistleDetector] Model loaded successfully (output key: \(outputName))")
      } else {
        print("⚠️ [WhistleDetector] Model loaded but output key not found, using fallback")
        modelOutputKey = "var_879"  // 기본값
      }
    } catch {
      print("❌ [WhistleDetector] Failed to load model: \(error)")
    }
  }
  
  // MARK: - Helper Methods

  /// 링 버퍼 크기를 동적으로 계산
  /// - Parameters:
  ///   - targetSeconds: 목표 시간 (초)
  ///   - frameLength: 실제 버퍼 프레임 수
  ///   - sampleRate: 샘플레이트
  /// - Returns: 필요한 링 버퍼 개수
  private func calculateRingBufferSize(targetSeconds: Double, frameLength: Int, sampleRate: Double) -> Int {
    // 1. 버퍼 하나의 시간 계산
    let bufferDuration = Double(frameLength) / sampleRate

    // 2. 호루라기 감지 간격 계산 (10번에 한 번)
    let detectionInterval = bufferDuration * Double(bufferCallInterval)

    // 3. 1초에 몇 번 호출되는지 계산
    let callsPerSecond = 1.0 / detectionInterval

    // 4. 목표 시간에 필요한 호출 횟수
    let requiredCalls = Int(ceil(targetSeconds * callsPerSecond))

    return max(requiredCalls, 5)  // 최소 5개는 유지
  }

  // MARK: - Detection

  // 최근 감지 확률 (UI 표시용)
  private(set) var lastWhistleProbability: Float = 0.0
  private(set) var lastRMSEnergy: Float = 0.0
  private(set) var lastDominantFrequency: Float = 0.0  // 주요 주파수
  private(set) var lastStage1Probability: Float = 0.0  // 1단계 확률
  private(set) var lastStage2Probability: Float = 0.0  // 2단계 확률

  /// Detect whistle from audio buffer
  /// - Parameter buffer: Audio PCM buffer
  /// - Returns: True if whistle detected
  func detectWhistle(from buffer: AVAudioPCMBuffer) -> Bool {
    guard let model = model else {
      print("⚠️ [WhistleDetector] Model not loaded")
      return false
    }

    // 1. 오디오 버퍼를 Float 배열로 변환
    guard let channelData = buffer.floatChannelData?[0] else {
      return false
    }

    let frameLength = Int(buffer.frameLength)
    let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

    // 쿨다운 체크 (최근 감지 후 일정 시간 경과 확인) - 하지만 값은 계속 업데이트
    var inCooldown = false
    if let lastTime = lastDetectionTime {
      let elapsed = Date().timeIntervalSince(lastTime)
      if elapsed < detectionCooldown {
        inCooldown = true  // 쿨다운 중이지만 값은 계속 업데이트
      }
    }

    // 1.5. 링 버퍼 크기를 실제 버퍼 정보로 동적 계산 (최초 1회만)
    ringBufferQueue.sync {
      if audioRingBuffer.isEmpty {
        let currentSampleRate = buffer.format.sampleRate
        ringBufferMaxSize = calculateRingBufferSize(
          targetSeconds: ringBufferTargetSeconds,
          frameLength: frameLength,
          sampleRate: currentSampleRate
        )
        print("📏 [WhistleDetector] Ring buffer size calculated: \(ringBufferMaxSize) buffers for \(ringBufferTargetSeconds)s")
        print("   ↳ Frame length: \(frameLength), Sample rate: \(currentSampleRate)Hz")
      }

      // 1.6. 링 버퍼에 오디오 저장
      audioRingBuffer.append(audioData)
      if audioRingBuffer.count > ringBufferMaxSize {
        audioRingBuffer.removeFirst()
      }
    }

    // 2. 에너지 체크 (소리가 실제로 있는지 확인)
    let rms = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count))

    lastRMSEnergy = rms  // UI 표시용 저장

    // 2.5. 호루라기 주파수 분석
    let currentSampleRate = buffer.format.sampleRate

    // 주파수 분석 (원본 오디오에서)
    let dominantFreq = findDominantFrequency(audioData, sampleRate: Float(currentSampleRate))
    lastDominantFrequency = dominantFreq

    // ==================== 모든 소리에 대해 모델 실행 (Stage 1) ====================
    // UI 표시를 위해 항상 S1 값 계산
    var audioDataForModel = audioData

    // 3. 리샘플링 (필요한 경우)
    if currentSampleRate != sampleRate {
      audioDataForModel = resample(audioDataForModel, from: currentSampleRate, to: sampleRate)
    }

    // 4. 버퍼 크기 맞추기 (패딩/자르기)
    if audioDataForModel.count < bufferSize {
      // 패딩 (부족한 부분은 0으로 채움)
      audioDataForModel.append(contentsOf: Array(repeating: 0.0, count: bufferSize - audioDataForModel.count))
    } else if audioDataForModel.count > bufferSize {
      // 자르기 (초과분 제거)
      audioDataForModel = Array(audioDataForModel.prefix(bufferSize))
    }

    var processData = audioDataForModel

    // 6. 정규화 (Z-score normalization: mean=0, std=1)
    let mean = processData.reduce(0.0, +) / Float(processData.count)
    let variance = processData.map { pow($0 - mean, 2) }.reduce(0.0, +) / Float(processData.count)
    let std = sqrt(variance)

    if std > 0.0001 {  // std가 0에 가까우면 정규화 스킵 (무음)
      processData = processData.map { ($0 - mean) / std }
    }

    // 7. MLMultiArray로 변환
    guard let mlArray = try? MLMultiArray(shape: [1, NSNumber(value: bufferSize)], dataType: .float32) else {
      print("❌ [WhistleDetector] Failed to create MLMultiArray")
      return false
    }

    for (index, value) in processData.enumerated() {
      mlArray[index] = NSNumber(value: value)
    }

    // 8. 예측 수행 (Stage 1 - 항상 실행)
    var whistleProb: Float = 0.0
    do {
      let input = WhistleClassifierInput(audio_input: mlArray)
      let output = try model.prediction(input: input)

      // 9. 결과 분석
      if let outputKey = modelOutputKey,
         let feature = output.featureValue(for: outputKey),
         let logits = feature.multiArrayValue,
         logits.count == 2 {

        // ⚠️ 라벨 인덱스 확정: 0 = non_whistle, 1 = whistle
        let nonLogit = logits[0].floatValue
        let whistleLogit = logits[1].floatValue

        // 디버깅: 원본 logits 값 출력
        print("🔍 [DEBUG] Raw logits - non_whistle: \(nonLogit), whistle: \(whistleLogit)")

        // softmax 계산
        let maxLogit = max(nonLogit, whistleLogit)
        let e0 = exp(nonLogit - maxLogit)
        let e1 = exp(whistleLogit - maxLogit)
        whistleProb = e1 / (e0 + e1)

        print("🔍 [DEBUG] Softmax probability - non_whistle: \(e0/(e0+e1)), whistle: \(whistleProb)")
      }
    } catch {
      print("❌ [WhistleDetector] Prediction failed: \(error)")
    }

    // Stage 1 확률 항상 저장 (UI 표시용)
    lastStage1Probability = whistleProb

    // ==================== 조건 체크 (실제 감지 판정용) ====================

    // 쿨다운 중이면 감지 안 함
    if inCooldown {
      lastStage2Probability = 0.0
      lastWhistleProbability = 0.0
      return false
    }

    // 에너지가 너무 낮으면 감지 안 함
    if rms < minEnergyThreshold {
      lastStage2Probability = 0.0
      lastWhistleProbability = 0.0
      consecutiveDetections = 0
      return false
    }

    // Band-pass filter 적용 (호루라기 검증용)
    let filteredAudio = applyBandPassFilter(audioData, lowCutoff: whistleFreqLow, highCutoff: whistleFreqHigh, sampleRate: Float(currentSampleRate))
    let filteredRMS = sqrt(filteredAudio.map { $0 * $0 }.reduce(0, +) / Float(filteredAudio.count))

    // 필터링 후 에너지가 너무 낮으면 호루라기 아님
    if filteredRMS < filteredEnergyThreshold {
      lastStage2Probability = 0.0
      lastWhistleProbability = 0.0
      consecutiveDetections = 0
      return false
    }

    // 주파수가 호루라기 범위가 아니면 감지 안 함
    if dominantFreq < whistleFreqLow || dominantFreq > whistleFreqHigh {
      lastStage2Probability = 0.0
      lastWhistleProbability = 0.0
      consecutiveDetections = 0
      return false
    }

    // ==================== 1단계 검증 ====================
    // 널널한 기준으로 "혹시 호루라기?" 체크
    if whistleProb < stage1Threshold {
      lastWhistleProbability = 0.0
      lastStage2Probability = 0.0
      consecutiveDetections = 0
      return false
    }

    // ==================== 2단계 검증 (슬라이딩 윈도우) ====================
    // 여러 구간을 검사해서 최대값 사용

    // 슬라이딩 윈도우 크기를 동적으로 계산
    let window1_0s = calculateRingBufferSize(targetSeconds: 1.0, frameLength: frameLength, sampleRate: currentSampleRate)
    let window0_7s = calculateRingBufferSize(targetSeconds: 0.7, frameLength: frameLength, sampleRate: currentSampleRate)
    let window0_5s = calculateRingBufferSize(targetSeconds: 0.5, frameLength: frameLength, sampleRate: currentSampleRate)

    let minRequiredBuffers = window0_5s  // 최소 윈도우 크기

    // Thread-safe ring buffer access
    let (bufferCount, windowsData) = ringBufferQueue.sync { () -> (Int, [(size: Int, audio: [Float], name: String)]) in
      let count = audioRingBuffer.count

      guard count >= minRequiredBuffers else {
        return (count, [])
      }

      let windows = [
        (size: window1_0s, name: "1.0s"),
        (size: window0_7s, name: "0.7s"),
        (size: window0_5s, name: "0.5s")
      ]

      var windowsData: [(size: Int, audio: [Float], name: String)] = []
      for window in windows {
        if count >= window.size {
          let windowAudio = audioRingBuffer.suffix(window.size).flatMap { $0 }
          windowsData.append((size: window.size, audio: windowAudio, name: window.name))
        }
      }

      return (count, windowsData)
    }

    guard bufferCount >= minRequiredBuffers else {
      lastWhistleProbability = 0.0
      lastStage2Probability = 0.0
      return false
    }

    var maxStage2Prob: Float = 0.0

    // 슬라이딩 윈도우: 최근 1초, 0.7초, 0.5초 세 구간 검사
    for (_, windowData) in windowsData.enumerated() { // Changed (index, windowData) to (_, windowData) since index is no longer used
      let enhancedAudio = enhanceWhistleAudio(windowData.audio, sampleRate: Float(currentSampleRate))
      let prob = runModelPrediction(enhancedAudio)

      if prob > maxStage2Prob {
        maxStage2Prob = prob
      }
    }

    let stage2Prob = maxStage2Prob

    // 2단계 확률 저장
    lastStage2Probability = stage2Prob
    lastWhistleProbability = stage2Prob  // UI에는 2단계 확률 표시

    // 2단계 임계값 체크
    if stage2Prob > stage2Threshold {
      consecutiveDetections += 1

      // 연속 감지 횟수가 요구사항을 충족하면 true
      if consecutiveDetections >= requiredConsecutiveDetections {
        print("✅ [WhistleDetector] WHISTLE CONFIRMED! S1: \(whistleProb), S2: \(stage2Prob)")
        lastDetectionTime = Date()
        consecutiveDetections = 0  // 리셋
        return true
      }
    } else {
      // 임계값 미달 시 카운터 리셋
      consecutiveDetections = 0
    }

    return false
  }
  
  // MARK: - Audio Processing Helpers

  /// Enhance whistle audio (증폭 + 고역 통과 필터 + 고주파 강조)
  private func enhanceWhistleAudio(_ samples: [Float], sampleRate: Float) -> [Float] {
    var enhanced = samples

    // 1. 증폭 (5배 - 과도한 증폭은 노이즈를 키움)
    enhanced = enhanced.map { $0 * 3.0 }

    // 2. 대역 통과 필터 (축구 경기 호루라기 주파수 대역)
    enhanced = applyBandPassFilter(enhanced, lowCutoff: whistleFreqLow, highCutoff: whistleFreqHigh, sampleRate: sampleRate)

    // 3. 고주파 강조 (호루라기 특성 부스트) - 오탐지를 유발할 수 있어 비활성화
    // enhanced = boostHighFrequencies(enhanced, sampleRate: sampleRate)

    // 4. 다이나믹 레인지 압축 (작은 소리는 키우고 큰 소리는 제한)
    enhanced = applyCompression(enhanced)

    // 5. 최종 정규화
    let maxVal = enhanced.map { abs($0) }.max() ?? 1.0
    if maxVal > 0.1 {  // 최소값 체크
      enhanced = enhanced.map { $0 / maxVal * 0.9 }
    }

    return enhanced
  }

  /// High-pass filter (간단한 1차 필터)
  private func applyHighPassFilter(_ samples: [Float], cutoffFreq: Float, sampleRate: Float) -> [Float] {
    let rc = 1.0 / (cutoffFreq * 2.0 * Float.pi)
    let dt = 1.0 / sampleRate
    let alpha = rc / (rc + dt)

    var filtered = [Float](repeating: 0, count: samples.count)
    filtered[0] = samples[0]

    for i in 1..<samples.count {
      filtered[i] = alpha * (filtered[i-1] + samples[i] - samples[i-1])
    }

    return filtered
  }

  /// Band-pass filter (호루라기 주파수 대역만 통과)
  private func applyBandPassFilter(_ samples: [Float], lowCutoff: Float, highCutoff: Float, sampleRate: Float) -> [Float] {
    // Low-pass 후 High-pass 적용
    var filtered = applyLowPassFilter(samples, cutoffFreq: highCutoff, sampleRate: sampleRate)
    filtered = applyHighPassFilter(filtered, cutoffFreq: lowCutoff, sampleRate: sampleRate)
    return filtered
  }

  /// Low-pass filter
  private func applyLowPassFilter(_ samples: [Float], cutoffFreq: Float, sampleRate: Float) -> [Float] {
    let rc = 1.0 / (cutoffFreq * 2.0 * Float.pi)
    let dt = 1.0 / sampleRate
    let alpha = dt / (rc + dt)

    var filtered = [Float](repeating: 0, count: samples.count)
    filtered[0] = samples[0]

    for i in 1..<samples.count {
      filtered[i] = filtered[i-1] + alpha * (samples[i] - filtered[i-1])
    }

    return filtered
  }

  /// Dynamic range compression (작은 소리 키우고 큰 소리 제한)
  private func applyCompression(_ samples: [Float]) -> [Float] {
    let threshold: Float = 0.3
    let ratio: Float = 4.0  // 4:1 compression

    return samples.map { sample in
      let abs_sample = abs(sample)
      if abs_sample > threshold {
        // 압축 적용
        let excess = abs_sample - threshold
        let compressed = threshold + excess / ratio
        return sample >= 0 ? compressed : -compressed
      } else {
        // 작은 소리는 증폭
        return sample * 1.5
      }
    }
  }

  /// Boost high frequencies (2000-4000Hz)
  private func boostHighFrequencies(_ samples: [Float], sampleRate: Float) -> [Float] {
    // 간단한 차분 필터로 고주파 강조
    var boosted = samples
    for i in 1..<samples.count {
      let highFreqComponent = samples[i] - samples[i-1]
      boosted[i] += highFreqComponent * 0.5  // 50% 부스트
    }
    return boosted
  }

  /// Run model prediction on processed audio
  private func runModelPrediction(_ samples: [Float]) -> Float {
    guard let model = model else {
      return 0.0
    }

    var audioData = samples

    // 리샘플링
    // 이미 16000Hz로 가정
    if audioData.count != bufferSize {
      // 버퍼 크기 맞추기
      if audioData.count < bufferSize {
        audioData.append(contentsOf: [Float](repeating: 0, count: bufferSize - audioData.count))
      } else {
        audioData = Array(audioData.prefix(bufferSize))
      }
    }

    // 정규화
    let mean = audioData.reduce(0, +) / Float(audioData.count)
    let variance = audioData.map { pow($0 - mean, 2) }.reduce(0, +) / Float(audioData.count)
    let std = sqrt(variance)
    if std > 0.0001 {
      audioData = audioData.map { ($0 - mean) / std }
    }

    // MLMultiArray 변환
    guard let mlArray = try? MLMultiArray(shape: [1, NSNumber(value: bufferSize)], dataType: .float32) else {
      return 0.0
    }

    for (index, value) in audioData.enumerated() {
      mlArray[index] = NSNumber(value: value)
    }

    // 예측
    do {
      let input = WhistleClassifierInput(audio_input: mlArray)
      let output = try model.prediction(input: input)

      guard let outputKey = modelOutputKey,
            let feature = output.featureValue(for: outputKey),
            let logits = feature.multiArrayValue,
            logits.count == 2 else {
        return 0.0
      }

      let nonLogit = logits[0].floatValue
      let whistleLogit = logits[1].floatValue

      // softmax 계산
      let maxLogit = max(nonLogit, whistleLogit)
      let e0 = exp(nonLogit - maxLogit)
      let e1 = exp(whistleLogit - maxLogit)
      let prob = e1 / (e0 + e1)

      return prob

    } catch {
      print("❌ [Stage 2] Prediction failed: \(error)")
      return 0.0
    }
  }

  /// Calculate Zero-Crossing Rate (호루라기는 높은 ZCR을 가짐)
  private func calculateZeroCrossingRate(_ samples: [Float]) -> Float {
    var crossings = 0
    for i in 1..<samples.count {
      if (samples[i] >= 0 && samples[i-1] < 0) || (samples[i] < 0 && samples[i-1] >= 0) {
        crossings += 1
      }
    }
    return Float(crossings) / Float(samples.count)
  }

  /// Calculate high-frequency energy ratio (고주파 에너지 / 전체 에너지)
  private func calculateHighFrequencyRatio(_ samples: [Float], sampleRate: Float) -> Float {
    let n = vDSP_Length(samples.count)
    let log2n = vDSP_Length(ceil(log2(Float(n))))
    let fftSize = Int(1 << log2n)

    guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
      return 0.0
    }
    defer { vDSP_destroy_fftsetup(fftSetup) }

    var realp = [Float](repeating: 0, count: fftSize / 2)
    var imagp = [Float](repeating: 0, count: fftSize / 2)
    var paddedSamples = samples

    if paddedSamples.count < fftSize {
      paddedSamples.append(contentsOf: [Float](repeating: 0, count: fftSize - paddedSamples.count))
    } else if paddedSamples.count > fftSize {
      paddedSamples = Array(paddedSamples.prefix(fftSize))
    }

    return realp.withUnsafeMutableBufferPointer { realpPtr in
        imagp.withUnsafeMutableBufferPointer { imagpPtr in
            var splitComplex = DSPSplitComplex(realp: realpPtr.baseAddress!, imagp: imagpPtr.baseAddress!)

            paddedSamples.withUnsafeBytes { ptr in
              ptr.bindMemory(to: DSPComplex.self).baseAddress.map {
                vDSP_ctoz($0, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
              }
            }

            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

            // 고주파 임계값 (1000Hz 이상)
            let highFreqThreshold = 1000.0
            let highFreqBin = Int((highFreqThreshold / Double(sampleRate)) * Double(fftSize))

            // 전체 에너지 및 고주파 에너지 계산
            let totalEnergy = magnitudes.reduce(0, +)
            let highFreqEnergy = magnitudes[highFreqBin...].reduce(0, +)

            return totalEnergy > 0 ? highFreqEnergy / totalEnergy : 0.0
        }
    }
  }

  /// Find dominant frequency using FFT
  private func findDominantFrequency(_ samples: [Float], sampleRate: Float) -> Float {
    let n = vDSP_Length(samples.count)
    let log2n = vDSP_Length(ceil(log2(Float(n))))
    let fftSize = Int(1 << log2n)

    // FFT 설정
    guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
      return 0.0
    }
    defer { vDSP_destroy_fftsetup(fftSetup) }

    // 입력 데이터를 split complex 형식으로 변환
    var realp = [Float](repeating: 0, count: fftSize / 2)
    var imagp = [Float](repeating: 0, count: fftSize / 2)
    var paddedSamples = samples

    // 패딩 (FFT 크기에 맞춤)
    if paddedSamples.count < fftSize {
      paddedSamples.append(contentsOf: [Float](repeating: 0, count: fftSize - paddedSamples.count))
    } else if paddedSamples.count > fftSize {
      paddedSamples = Array(paddedSamples.prefix(fftSize))
    }

    return realp.withUnsafeMutableBufferPointer { realpPtr in
        imagp.withUnsafeMutableBufferPointer { imagpPtr in
            var splitComplex = DSPSplitComplex(realp: realpPtr.baseAddress!, imagp: imagpPtr.baseAddress!)

            paddedSamples.withUnsafeBytes { ptr in
                ptr.bindMemory(to: DSPComplex.self).baseAddress.map {
                    vDSP_ctoz($0, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                }
            }

            // FFT 수행
            vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

            // 크기(magnitude) 계산
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

            // DC 성분(0Hz) 제거
            magnitudes[0] = 0

            // 최대 크기를 가진 주파수 찾기
            var maxMagnitude: Float = 0
            var maxIndex: vDSP_Length = 0
            vDSP_maxvi(magnitudes, 1, &maxMagnitude, &maxIndex, vDSP_Length(magnitudes.count))

            // 주파수 계산
            let frequency = Float(maxIndex) * sampleRate / Float(fftSize)
            return frequency
        }
    }
  }

  /// Simple resampling (linear interpolation)
  private func resample(_ input: [Float], from fromRate: Double, to toRate: Double) -> [Float] {
    let ratio = fromRate / toRate
    let outputLength = Int(Double(input.count) / ratio)
    var output = [Float](repeating: 0, count: outputLength)
    
    for i in 0..<outputLength {
      let srcIndex = Double(i) * ratio
      let index0 = Int(srcIndex)
      let index1 = min(index0 + 1, input.count - 1)
      let fraction = Float(srcIndex - Double(index0))
      
      output[i] = input[index0] * (1 - fraction) + input[index1] * fraction
    }
    
    return output
  }
}
