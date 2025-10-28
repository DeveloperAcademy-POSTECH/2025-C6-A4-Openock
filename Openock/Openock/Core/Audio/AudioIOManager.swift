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

fileprivate final class AudioPreprocessor {
  private let sampleRate: Double
  private let channels: Int
  private let frameSamples: Int
  private var x1: [Float]
  private var y1: [Float]
  private let hpAlpha: Float
  private var emaRms: Float = 0.0
  private let emaA: Float = 0.95
  private let gateAttenuation: Float = pow(10.0, -12.0/20.0)
  private let gateOpenRatio: Float = 2.0
  
  init(sampleRate: Double, channels: Int, frameMs: Int = 20, hpCutoff: Double = 120.0) {
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
    guard let out = AVAudioPCMBuffer(pcmFormat: inBuf.format, frameCapacity: inBuf.frameLength) else { return inBuf }
    out.frameLength = inBuf.frameLength
    guard let srcBase = inBuf.floatChannelData, let dstBase = out.floatChannelData else { return inBuf }
    
    let n = Int(inBuf.frameLength)
    var idx = 0
    while idx < n {
      let end = min(idx + frameSamples, n)
      let frameCount = end - idx
      
      var accum: Float = 0
      for ch in 0..<channels {
        let src = srcBase[ch]
        let dst = dstBase[ch]
        var prevX = x1[ch]
        var prevY = y1[ch]
        let a = hpAlpha
        var i = idx
        while i < end {
          let x = src[i]
          let y = a * (prevY + x - prevX)
          dst[i] = y
          prevX = x
          prevY = y
          accum += y*y
          i += 1
        }
        x1[ch] = prevX
        y1[ch] = prevY
      }
      
      let frameRms = sqrt(accum / Float(frameCount * channels))
      if frameRms < emaRms * 1.5 || emaRms == 0 {
        emaRms = emaA * emaRms + (1 - emaA) * frameRms
      }
      let openThresh = max(emaRms * gateOpenRatio, 1e-6)
      let applyGate = frameRms < openThresh
      
      if applyGate {
        for ch in 0..<channels {
          let dst = dstBase[ch]
          var i = idx
          while i < end {
            dst[i] *= gateAttenuation
            i += 1
          }
        }
      }
      
      idx = end
    }
    
    return out
  }
}

// MARK: - Audio IO Manager

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
      channels: AVAudioChannelCount(streamFormat.mChannelsPerFrame),
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
