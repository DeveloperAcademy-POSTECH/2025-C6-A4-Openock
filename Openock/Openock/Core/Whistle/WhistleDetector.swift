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
  private let sampleRate: Double = 16000  // 모델 학습 시 사용된 샘플레이트
  private let bufferSize = 16000  // 1초 버퍼

  // 2단계 검증 시스템
  private let stage1Threshold: Float = 0.50  // 1단계: 매우 널널한 기준 (의심 구간 포착)
  private let stage2Threshold: Float = 0.75  // 2단계: 매우 엄격한 기준 (최종 확인)

  // 연속 감지 방지
  private var lastDetectionTime: Date?
  private let detectionCooldown: TimeInterval = 5.0  // 5초 쿨다운

  // 연속 검증 (여러 프레임 연속으로 감지되어야 함)
  private var consecutiveDetections: Int = 0
  private let requiredConsecutiveDetections: Int = 1  // 즉각적인 반응을 위해 1번만

  // 오디오 링 버퍼 (최근 2초 유지 - 축구 중계용)
  private var audioRingBuffer: [[Float]] = []
  private let ringBufferMaxSize = 120  // 약 2초치
  
  // MARK: - Initialization
  
  init() {
    loadModel()
  }
  
  private func loadModel() {
    do {
      let config = MLModelConfiguration()
      config.computeUnits = .cpuAndNeuralEngine  // Neural Engine 사용
      
      model = try WhistleClassifier(configuration: config)
      print("✅ [WhistleDetector] Model loaded successfully")
    } catch {
      print("❌ [WhistleDetector] Failed to load model: \(error)")
    }
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

    // 쿨다운 체크 (최근 감지 후 일정 시간 경과 확인)
    if let lastTime = lastDetectionTime {
      let elapsed = Date().timeIntervalSince(lastTime)
      if elapsed < detectionCooldown {
        return false  // 쿨다운 중이면 감지하지 않음
      }
    }

    // 1. 오디오 버퍼를 Float 배열로 변환
    guard let channelData = buffer.floatChannelData?[0] else {
      return false
    }

    let frameLength = Int(buffer.frameLength)
    var audioData = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

    // 1.5. 링 버퍼에 오디오 저장 (최근 1초 유지)
    audioRingBuffer.append(audioData)
    if audioRingBuffer.count > ringBufferMaxSize {
      audioRingBuffer.removeFirst()
    }

    // 2. 에너지 체크 (소리가 실제로 있는지 확인)
    let rms = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count))
    let energyThreshold: Float = 0.001  // 매우 낮춤 (축구 중계 호루라기는 멀리서 들림)

    lastRMSEnergy = rms  // UI 표시용 저장

    if rms < energyThreshold {
      // 거의 완전 무음만 스킵
      lastWhistleProbability = 0.0
      lastDominantFrequency = 0.0
      lastStage1Probability = 0.0
      lastStage2Probability = 0.0
      consecutiveDetections = 0
      return false
    }

    // 2.5. 호루라기 주파수 필터링 및 검증 (좁은 범위)
    let currentSampleRate = buffer.format.sampleRate

    // Band-pass filter 적용 (1500-5000Hz - 더 넓은 호루라기 주파수 범위)
    audioData = applyBandPassFilter(audioData, lowCutoff: 1500.0, highCutoff: 5000.0, sampleRate: Float(currentSampleRate))

    // 필터링 후 에너지 체크
    let filteredRMS = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count))

    print("🔊 [WhistleDetector] Filtered energy (1500-5000Hz): \(filteredRMS)")

    // 필터링 후 에너지가 너무 낮으면 호루라기 아님
    if filteredRMS < 0.004 {
      print("🚫 [WhistleDetector] Not enough energy in whistle frequency range (< 0.004)")
      lastWhistleProbability = 0.0
      lastStage1Probability = 0.0
      lastStage2Probability = 0.0
      lastDominantFrequency = 0.0
      consecutiveDetections = 0
      return false
    }

    // 주파수 분석 (필터링된 오디오에서)
    let dominantFreq = findDominantFrequency(audioData, sampleRate: Float(currentSampleRate))
    lastDominantFrequency = dominantFreq

    print("🎼 [WhistleDetector] Dominant frequency (after filter): \(dominantFreq) Hz")

    // 필터링 후에도 주파수가 1500-5000Hz 범위인지 확인
    if dominantFreq < 1500.0 || dominantFreq > 5000.0 {
      print("🚫 [WhistleDetector] Dominant frequency out of whistle range: \(dominantFreq) Hz (expected 1500-5000 Hz)")
      lastWhistleProbability = 0.0
      lastStage1Probability = 0.0
      lastStage2Probability = 0.0
      consecutiveDetections = 0
      return false
    }

    print("✅ [WhistleDetector] Frequency filtering passed (\(dominantFreq) Hz)")

    // 3. 리샘플링 (필요한 경우)
    if currentSampleRate != sampleRate {
      audioData = resample(audioData, from: currentSampleRate, to: sampleRate)
    }

    // 4. 버퍼 크기 맞추기 (패딩/자르기)
    if audioData.count < bufferSize {
      // 패딩 (부족한 부분은 0으로 채움)
      audioData.append(contentsOf: Array(repeating: 0.0, count: bufferSize - audioData.count))
    } else if audioData.count > bufferSize {
      // 자르기 (초과분 제거)
      audioData = Array(audioData.prefix(bufferSize))
    }

    var processData = audioData

    // 6. 정규화 (Z-score normalization: mean=0, std=1)
    // Wav2Vec2 모델은 정규화된 입력을 기대함
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

    // 8. 예측 수행
    do {
      let input = WhistleClassifierInput(audio_input: mlArray)
      let output = try model.prediction(input: input)

      // 9. 결과 분석
      guard let provider = output as? MLFeatureProvider,
            let feature = provider.featureValue(for: "var_879"), // 필요시 출력 키 이름 수정
            let logits = feature.multiArrayValue,
            logits.count == 2 else {
        print("❌ [WhistleDetector] Could not access model output")
        return false
      }
      
      // ⚠️ 라벨 인덱스 확정: 0 = non_whistle, 1 = whistle
      let nonLogit = logits[0].floatValue
      let whistleLogit = logits[1].floatValue
      
      // 1단계는 단순한 softmax만 사용 (너무 보수적이면 놓침)
      let maxLogit = max(nonLogit, whistleLogit)
      let e0 = exp(nonLogit - maxLogit)
      let e1 = exp(whistleLogit - maxLogit)
      let whistleProb = e1 / (e0 + e1)

      print("📊 [WhistleDetector] Stage 1 raw probability: \(whistleProb) (threshold: \(stage1Threshold))")

      // 1단계 확률 저장
      lastStage1Probability = whistleProb

      // ==================== 1단계 검증 ====================
      // 널널한 기준으로 "혹시 호루라기?" 체크
      if whistleProb < stage1Threshold {
        print("❌ [Stage 1] Failed - probability too low")
        lastWhistleProbability = whistleProb
        lastStage2Probability = 0.0
        consecutiveDetections = 0
        return false
      }

      print("✅ [Stage 1] Passed - potential whistle detected!")
      print("🔄 [Stage 2] Starting enhanced verification...")

      // ==================== 2단계 검증 (슬라이딩 윈도우) ====================
      // 여러 구간을 검사해서 최대값 사용
      guard audioRingBuffer.count >= 60 else {
        print("⚠️ [Stage 2] Not enough audio buffer, skipping stage 2")
        lastWhistleProbability = whistleProb
        lastStage2Probability = 0.0
        return false
      }

      var maxStage2Prob: Float = 0.0
      var bestWindowIndex = 0

      // 슬라이딩 윈도우: 최근 1초, 0.7초, 0.5초 세 구간 검사
      let windows = [
        (size: 60, name: "1.0s"),
        (size: 42, name: "0.7s"),
        (size: 30, name: "0.5s")
      ]

      for (index, window) in windows.enumerated() {
        guard audioRingBuffer.count >= window.size else { continue }

        let windowAudio = audioRingBuffer.suffix(window.size).flatMap { $0 }
        let enhancedAudio = enhanceWhistleAudio(windowAudio, sampleRate: Float(currentSampleRate))
        let prob = runModelPrediction(enhancedAudio)

        print("   Window \(index+1) (\(window.name)): \(String(format: "%.3f", prob))")

        if prob > maxStage2Prob {
          maxStage2Prob = prob
          bestWindowIndex = index + 1
        }
      }

      let stage2Prob = maxStage2Prob

      print("📊 [Stage 2] Best probability: \(String(format: "%.3f", stage2Prob)) from window #\(bestWindowIndex) (threshold: \(stage2Threshold))")
      print("   ↳ Enhancement: 5x amplification + Band-pass (1500-5000Hz) + Compression")

      // 2단계 확률 저장
      lastStage2Probability = stage2Prob
      lastWhistleProbability = stage2Prob  // UI에는 2단계 확률 표시

      // 2단계 임계값 체크
      if stage2Prob > stage2Threshold {
        consecutiveDetections += 1
        print("🎵 [WhistleDetector] Whistle candidate detected! (consecutive: \(consecutiveDetections)/\(requiredConsecutiveDetections))")

        // 연속 감지 횟수가 요구사항을 충족하면 true
        if consecutiveDetections >= requiredConsecutiveDetections {
          print("✅ [WhistleDetector] WHISTLE CONFIRMED! Probability: \(whistleProb)")
          lastDetectionTime = Date()
          consecutiveDetections = 0  // 리셋
          return true
        }
      } else {
        // 임계값 미달 시 카운터 리셋
        if consecutiveDetections > 0 {
          print("⚠️ [WhistleDetector] Detection interrupted. Probability: \(whistleProb)")
        }
        consecutiveDetections = 0
      }

      return false
      
    } catch {
      print("❌ [WhistleDetector] Prediction failed: \(error)")
      return false
    }
  }
  
  // MARK: - Audio Processing Helpers

  /// Enhance whistle audio (증폭 + 고역 통과 필터 + 고주파 강조)
  private func enhanceWhistleAudio(_ samples: [Float], sampleRate: Float) -> [Float] {
    var enhanced = samples

    // 1. 증폭 (5배 - 과도한 증폭은 노이즈를 키움)
    enhanced = enhanced.map { $0 * 5.0 }

    // 2. 대역 통과 필터 (1500-5000Hz만 통과 - 더 넓은 호루라기 주파수 대역)
    enhanced = applyBandPassFilter(enhanced, lowCutoff: 1500.0, highCutoff: 5000.0, sampleRate: sampleRate)

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
    let currentRate = Double(sampleRate)  // 이미 16000Hz로 가정
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

      guard let provider = output as? MLFeatureProvider,
            let feature = provider.featureValue(for: "var_879"),
            let logits = feature.multiArrayValue,
            logits.count == 2 else {
        return 0.0
      }

      let nonLogit = logits[0].floatValue
      let whistleLogit = logits[1].floatValue

      // 간단한 softmax (Temperature 없이 - 2단계는 원본 확률 사용)
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

    var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

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

    var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

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
