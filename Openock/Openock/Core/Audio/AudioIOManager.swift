//
//  AudioIOManager.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

/*
 Audio IO Manager
 
 Abstract:
 Manages CoreAudio IO operations including audio device IO proc, buffer processing,
 and audio preprocessing (HPF and noise gate).
 */

import Foundation
import AVFoundation
import CoreAudio

// MARK: - Audio Preprocessor

// HPF가 120헤르츠(저음) 이하를 잘라내는 역할인데 이걸 완화하겠다
// 노이즈 게이트는 동적으로 소리 크기 받아서 특정 소리 크기 이하이면 잘라내는 역할인데 이걸 완화하겠다
// 모노화는 스테레오인 경우가 많고 이 경우 목소리는 센터 배경음은 좌 우 배치인데 왜곡이 적도록 좌 우를 평균내버리는거임
// 영화, 유튜브, 음악 대부분의 스테레오 오디오는 mid-side 방식임
// left = mid + side, right = mid - side 그래서 더해서 나누면 중앙 증폭이 될 것 같다 이런 접근임 ㅇㅇ

fileprivate final class AudioPreprocessor {
  private let sampleRate: Double
  private let channels: Int
  private let frameSamples: Int
  private var x1: [Float]
  private var y1: [Float]
  private let hpAlpha: Float
  private var emaRms: Float = 0.0
  private let emaA: Float = 0.95
  
  // 게이트 관련 (기본 OFF)
  private let useNoiseGate: Bool = false
  private let gateAttenuation: Float = pow(10.0, -6.0/20.0) // -6 dB 정도만 살짝 줄임
  private let gateOpenRatio: Float = 1.5
  
  // 컷오프 완화: 90Hz 기본
  init(sampleRate: Double, channels: Int, frameMs: Int = 20, hpCutoff: Double = 90.0) {
    self.sampleRate = sampleRate
    self.channels = max(1, channels)
    self.frameSamples = max(1, Int((sampleRate * Double(frameMs)) / 1000.0))
    self.x1 = Array(repeating: 0, count: self.channels)
    self.y1 = Array(repeating: 0, count: self.channels)
    let dt = 1.0 / sampleRate
    let rc = 1.0 / (2.0 * Double.pi * hpCutoff)
    self.hpAlpha = Float(rc / (rc + dt))
  }
  
  func process(_ inBuf: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
    let n = Int(inBuf.frameLength)
    guard n > 0 else { return inBuf }

    // 출력 버퍼 준비 (모노 혹은 동일 포맷 유지)
    let outFormat: AVAudioFormat
    if channels > 1 {
      // 모노화된 포맷 생성
      outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                sampleRate: inBuf.format.sampleRate,
                                channels: 1,
                                interleaved: false)!
    } else {
      outFormat = inBuf.format
    }

    guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: inBuf.frameLength) else {
      return inBuf
    }
    out.frameLength = inBuf.frameLength

    guard let srcBase = inBuf.floatChannelData else { return inBuf }
    guard let dstBase = out.floatChannelData else { return inBuf }

    // ----- 모노화 (스테레오인 경우에만) -----
    if channels > 1 {
      let L = srcBase[0]
      let R = srcBase[1]
      let dst = dstBase[0]
      for i in 0..<n {
        dst[i] = 0.5 * (L[i] + R[i]) // 중앙 강조
      }
    } else {
      // 모노 입력이면 그대로 복사
      let src = srcBase[0]
      let dst = dstBase[0]
      dst.assign(from: src, count: n)
    }

    // ----- HPF 적용 (90Hz) -----
    let a = hpAlpha
    var prevX: Float = x1[0]
    var prevY: Float = y1[0]
    let dst = dstBase[0]
    for i in 0..<n {
      let x = dst[i]
      let y = a * (prevY + x - prevX)
      dst[i] = y
      prevX = x
      prevY = y
    }
    x1[0] = prevX
    y1[0] = prevY

    // ----- Noise Gate (기본 OFF) -----
    guard useNoiseGate else { return out }
    var sum: Float = 0
    for i in 0..<n { sum += dst[i] * dst[i] }
    let rms = sqrt(sum / Float(n))
    if rms < emaRms * 1.5 || emaRms == 0 {
      emaRms = emaA * emaRms + (1 - emaA) * rms
    }
    let openThresh = max(emaRms * gateOpenRatio, 1e-6)
    let applyGate = rms < openThresh
    if applyGate {
      for i in 0..<n { dst[i] *= gateAttenuation }
    }

    return out
  }
}



// MARK: - Audio IO Manager

// ✅ ADD: 저역(베이스) 레벨 콜백 타입
typealias LowBandCallback = (Float) -> Void

class AudioIOManager {
  
  typealias AudioBufferCallback = (AVAudioPCMBuffer) -> Void
  typealias AudioLevelCallback = (Float) -> Void
  
  private var deviceID: AudioObjectID = kAudioObjectUnknown
  private var ioProcID: AudioDeviceIOProcID?
  private var audioFormat: AVAudioFormat?
  private var preproc: AudioPreprocessor?
  private var preprocEnabled: Bool = true
  
  private var bufferCallback: AudioBufferCallback?
  private var levelCallback: AudioLevelCallback?
  private var bufferCallCount = 0
  var isPaused = false

  // ✅ ADD: 저역(베이스) 레벨 전송용 상태
  private var lowBandCallback: LowBandCallback?
  private var lpfEnv: Float = 0
  private var lpfAlpha: Float = 0
  private var sampleRateCache: Double = 48000

  // ✅ ADD: 밴드패스(저컷/고컷)용 상태 & 계수
  private var sigLPF_Low:  Float = 0    // 저컷 기준 LPF 결과
  private var sigLPF_High: Float = 0    // 고컷 기준 LPF 결과
  private var lowAlpha:  Float = 0      // 저컷(느린 LPF)
  private var highAlpha: Float = 0      // 고컷(빠른 LPF)
  
  /// Get the audio format for a given device
  func getDeviceFormat(deviceID: AudioObjectID) -> AVAudioFormat? {
    var propertyAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamFormat,
      mScope: kAudioDevicePropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain
    )
    
    var streamFormat = AudioStreamBasicDescription()
    var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    
    let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &streamFormat)
    
    guard status == kAudioHardwareNoError else {
      return nil
    }
    
    return AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: streamFormat.mSampleRate,
      channels: AVAudioChannelCount(streamFormat.mChannelsPerFrame), // 이게 스테레오일 경우를 저장하고 있는 부분임
      interleaved: false
    )
  }
  
  /// Start audio IO on the specified device
  /// - Parameters:
  ///   - deviceID: The audio device ID
  ///   - bufferCallback: Called when audio buffer is ready
  ///   - levelCallback: Called with audio level updates
  /// - Returns: True if successful
  func startIO(deviceID: AudioObjectID,
               bufferCallback: @escaping AudioBufferCallback,
               levelCallback: @escaping AudioLevelCallback) -> Bool {
    
    print("🎤 [AudioIOManager] Starting IO on device \(deviceID)...")
    
    self.deviceID = deviceID
    self.bufferCallback = bufferCallback
    self.levelCallback = levelCallback
    self.bufferCallCount = 0
    
    // Get device format
    guard let format = getDeviceFormat(deviceID: deviceID) else {
      print("❌ [AudioIOManager] Failed to get device format")
      return false
    }
    
    self.audioFormat = format
    print("✅ [AudioIOManager] Audio format: \(format.sampleRate)Hz, \(format.channelCount) channels")
    
    // Initialize preprocessor
    self.preproc = AudioPreprocessor(
      sampleRate: Double(format.sampleRate),
      channels: Int(format.channelCount),
      frameMs: 20
    )
    
    // Create IO proc
    let managerPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    
    var ioProcID: AudioDeviceIOProcID?
    let createStatus = AudioDeviceCreateIOProcID(deviceID, audioIOProc, managerPtr, &ioProcID)
    
    guard createStatus == kAudioHardwareNoError else {
      print("❌ [AudioIOManager] Failed to create IO proc: \(createStatus)")
      return false
    }
    
    self.ioProcID = ioProcID
    
    // Start IO
    let startStatus = AudioDeviceStart(deviceID, ioProcID)
    guard startStatus == kAudioHardwareNoError else {
      print("❌ [AudioIOManager] Failed to start audio device: \(startStatus)")
      AudioDeviceDestroyIOProcID(deviceID, ioProcID!)
      self.ioProcID = nil
      return false
    }
    
    print("✅ [AudioIOManager] Audio IO started successfully")
    return true
  }

  // ✅ ADD: 저역(베이스) 전용 레벨 콜백과 컷오프 설정  (밴드패스 30~90Hz 근사 + 엔벌로프 평활)
  func setLowBandMonitoring(callback: @escaping LowBandCallback, lowpassCutoffHz: Double = 150.0) {
    self.lowBandCallback = callback
    let fs = max(8_000.0, Double(self.audioFormat?.sampleRate ?? sampleRateCache))

    // 밴드패스 범위(말소리 기본음을 피하기 위해 상한을 낮게 잡음)
    let fLow:  Double = 30.0   // 저컷(하이패스 역할)
    let fHigh: Double = 90.0   // 고컷(로우패스 역할)

    // 1-pole LPF 계수: y += α(x - y), α = 1 - exp(-2π f / fs)
    self.lowAlpha  = Float(1.0 - exp(-2.0 * Double.pi * fLow  / fs))  // 느린 LPF
    self.highAlpha = Float(1.0 - exp(-2.0 * Double.pi * fHigh / fs))  // 빠른 LPF

    // 엔벌로프 평활(느리게): 6Hz 근처
    let envHz = 6.0
    self.lpfAlpha = Float(1.0 - exp(-2.0 * Double.pi * envHz / fs))

    self.sampleRateCache = fs
  }
  
  /// Stop audio IO
  func stopIO() {
    guard let ioProcID = ioProcID else { return }
    
    print("🛑 [AudioIOManager] Stopping audio IO...")
    AudioDeviceStop(deviceID, ioProcID)
    AudioDeviceDestroyIOProcID(deviceID, ioProcID)
    self.ioProcID = nil
    self.preproc = nil
    self.bufferCallback = nil
    self.levelCallback = nil
    print("✅ [AudioIOManager] Audio IO stopped")
  }
  
  /// Process audio buffer from IO proc
  func processAudioBuffer(_ bufferList: UnsafePointer<AudioBufferList>, frameCount: UInt32) {
    if isPaused {
      return
    }
    
    guard let audioFormat = audioFormat else {
      if bufferCallCount == 0 {
        print("⚠️ [AudioIOManager] Missing audioFormat")
      }
      return
    }
    
    bufferCallCount += 1
    if bufferCallCount <= 10 || bufferCallCount % 100 == 0 {
      print("🎵 [AudioIOManager] Processing buffer #\(bufferCallCount): \(frameCount) frames")
    }
    
    // Create AVAudioPCMBuffer
    guard let pcmBuffer = AVAudioPCMBuffer(
      pcmFormat: audioFormat,
      frameCapacity: AVAudioFrameCount(frameCount)
    ) else {
      return
    }
    
    pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
    
    // Copy audio data from AudioBufferList to AVAudioPCMBuffer
    let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
    let channels = Int(audioFormat.channelCount)
    
    if abl.count == 1, let srcPtr = abl[0].mData?.assumingMemoryBound(to: Float.self), abl[0].mNumberChannels > 1 {
      // Interleaved
      guard let dstBase = pcmBuffer.floatChannelData else { return }
      let totalFrames = Int(frameCount)
      let stride = channels
      for ch in 0..<channels {
        let dst = dstBase[ch]
        var s = srcPtr.advanced(by: ch)
        for f in 0..<totalFrames {
          dst[f] = s.pointee
          s = s.advanced(by: stride)
        }
      }
    } else {
      // Non-interleaved
      for (index, srcBuffer) in abl.enumerated() {
        guard index < channels,
              let dst = pcmBuffer.floatChannelData?[index],
              let srcPtr = srcBuffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
        dst.update(from: srcPtr, count: Int(frameCount))
      }
    }
    
    // Preprocess (HPF + noise gate)
    let enhancedBuffer: AVAudioPCMBuffer
    if preprocEnabled, let pp = preproc {
      enhancedBuffer = pp.process(pcmBuffer)
    } else {
      enhancedBuffer = pcmBuffer
    }
    
    // Send to callback
    bufferCallback?(enhancedBuffer)
    
    // Calculate audio level (every 10 buffers)
    if bufferCallCount % 10 == 0, let channelData = enhancedBuffer.floatChannelData?[0] {
      var sum: Float = 0.0
      let frameLength = Int(enhancedBuffer.frameLength)
      
      var i = 0
      while i < frameLength {
        let sample = channelData[i]
        sum += sample * sample
        i += 4
      }
      
      let avgSum = sum * 4 / Float(frameLength)
      let rms = sqrt(avgSum)
      let db = 20 * log10(max(rms, 0.000001))
      let normalizedLevel = max(0.0, min(1.0, (db + 60) / 60))
      
      levelCallback?(normalizedLevel)
    }

    // ✅ REPLACE: 저역(베이스) 전용 레벨 계산 및 전달 (밴드패스 30~90Hz 근사, 매 10버퍼)
    if bufferCallCount % 10 == 0,
       let lowBandCallback = self.lowBandCallback,
       let srcPtr = pcmBuffer.floatChannelData {
      
      let chCount = Int(audioFormat.channelCount)
      let n = Int(pcmBuffer.frameLength)
      
      if chCount >= 2 {
        let L = srcPtr[0], R = srcPtr[1]
        for i in 0..<n {
          // 1) 모노 합성
          let m = 0.5 * (L[i] + R[i])
          // 2) 밴드패스 근사: 고컷 LPF - 저컷 LPF
          sigLPF_Low  += lowAlpha  * (m - sigLPF_Low)   // 저컷(느림)
          sigLPF_High += highAlpha * (m - sigLPF_High)  // 고컷(빠름)
          let band = sigLPF_High - sigLPF_Low           // 대략 30~90Hz 성분
          // 3) 에너지화 후 엔벌로프 평활
          let e = band * band
          lpfEnv += lpfAlpha * (e - lpfEnv)
        }
      } else {
        let M = srcPtr[0]
        for i in 0..<n {
          sigLPF_Low  += lowAlpha  * (M[i] - sigLPF_Low)
          sigLPF_High += highAlpha * (M[i] - sigLPF_High)
          let band = sigLPF_High - sigLPF_Low
          let e = band * band
          lpfEnv += lpfAlpha * (e - lpfEnv)
        }
      }
      
      // 0~1 스케일로 부드럽게 압축 (둔감하게)
      let k: Float = 10.0
      let bass = 1.0 - expf(-k * max(0, lpfEnv))
      let bassClamped = max(0.0, min(1.0, bass))
      lowBandCallback(bassClamped)
    }
  }
  
  deinit {
    stopIO()
  }
}

// MARK: - Audio IO Proc Callback

private func audioIOProc(
  inDevice: AudioObjectID,
  inNow: UnsafePointer<AudioTimeStamp>,
  inInputData: UnsafePointer<AudioBufferList>,
  inInputTime: UnsafePointer<AudioTimeStamp>,
  outOutputData: UnsafeMutablePointer<AudioBufferList>,
  inOutputTime: UnsafePointer<AudioTimeStamp>,
  inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let clientData = inClientData else { return kAudioHardwareNoError }
  
  let manager = Unmanaged<AudioIOManager>.fromOpaque(clientData).takeUnretainedValue()
  
  if inInputData.pointee.mNumberBuffers > 0 {
    let buffer = inInputData.pointee.mBuffers
    let frameCount = buffer.mDataByteSize / UInt32(MemoryLayout<Float>.size) / UInt32(buffer.mNumberChannels)
    manager.processAudioBuffer(inInputData, frameCount: frameCount)
  }
  
  return kAudioHardwareNoError
}
