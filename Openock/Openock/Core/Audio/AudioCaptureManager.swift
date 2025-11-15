//
//  AudioCaptureManager.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

/*
 Audio Capture Manager
 
 Abstract:
 Manages CoreAudio Tap and Aggregate Device creation for full system audio capture.
 Responsible for setting up the audio pipeline but not processing audio data.
 */

import Foundation
import CoreAudio

class AudioCaptureManager {
  
  private(set) var tapID: AudioObjectID = kAudioObjectUnknown
  private(set) var aggregateDeviceID: AudioObjectID = kAudioObjectUnknown
  
  /// Get all audio processes currently running on the system
  func getAllAudioProcesses() -> [AudioObjectID] {
    var processListAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    
    var propertySize: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &processListAddress, 0, nil, &propertySize)
    let processCount = Int(propertySize) / MemoryLayout<AudioObjectID>.stride
    var processList: [AudioObjectID] = Array(repeating: 0, count: processCount)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &processListAddress, 0, nil, &propertySize, &processList)
    
    return processList
  }
  
  /// Create an audio tap for specified processes
  /// - Parameter processes: Array of process IDs to capture audio from
  /// - Returns: Audio tap ID if successful, nil otherwise
  func createAudioTap(processes: [AudioObjectID]) -> AudioObjectID? {
    print("🔧 [AudioCaptureManager] Creating audio tap for \(processes.count) processes...")
    
    let tapDescription = CATapDescription()
    tapDescription.name = "Full System Audio Tap"
    tapDescription.processes = processes
    tapDescription.isPrivate = false
    tapDescription.muteBehavior = .unmuted
    tapDescription.isMixdown = true
    tapDescription.isMono = false
    
    var tapID = AudioObjectID(kAudioObjectUnknown)
    let status = AudioHardwareCreateProcessTap(tapDescription, &tapID)
    
    guard status == kAudioHardwareNoError else {
      print("❌ [AudioCaptureManager] Failed to create audio tap: \(status)")
      return nil
    }
    
    self.tapID = tapID
    print("✅ [AudioCaptureManager] Audio tap created: \(tapID)")
    return tapID
  }
  
  /// Create an aggregate device for audio capture
  /// - Returns: Aggregate device ID if successful, nil otherwise
  func createAggregateDevice() -> AudioObjectID? {
    print("🔧 [AudioCaptureManager] Creating aggregate device...")
    
    let description = [
      kAudioAggregateDeviceNameKey: "Full System Audio Capture Device",
      kAudioAggregateDeviceUIDKey: "com.openock.systemaudiocapture"
    ]
    
    var aggregateID: AudioObjectID = 0
    let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
    
    guard status == kAudioHardwareNoError else {
      print("❌ [AudioCaptureManager] Failed to create aggregate device: \(status)")
      return nil
    }
    
    self.aggregateDeviceID = aggregateID
//    print("✅ [AudioCaptureManager] Aggregate device created: \(aggregateID)")
    return aggregateID
  }
  
  /// Add an audio tap to an aggregate device
  /// - Parameters:
  ///   - tapID: The audio tap ID to add
  ///   - deviceID: The aggregate device ID
  /// - Returns: True if successful
  func addTapToAggregateDevice(tapID: AudioObjectID, deviceID: AudioObjectID) -> Bool {
    print("🔧 [AudioCaptureManager] Adding tap \(tapID) to aggregate device \(deviceID)...")
    
    // Get tap UID
    var tapUIDAddress = AudioObjectPropertyAddress(
      mSelector: kAudioTapPropertyUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var tapUID: CFString = "" as CFString
    var tapUIDSize = UInt32(MemoryLayout<CFString>.stride)
    _ = withUnsafeMutablePointer(to: &tapUID) { ptr in
      AudioObjectGetPropertyData(tapID, &tapUIDAddress, 0, nil, &tapUIDSize, ptr)
    }
    
    print("✅ [AudioCaptureManager] Tap UID: \(tapUID as String)")
    
    // Add tap to aggregate device
    var tapListAddress = AudioObjectPropertyAddress(
      mSelector: kAudioAggregateDevicePropertyTapList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    
    let tapUIDString = tapUID as String
    var tapArray = [tapUIDString] as CFArray
    let tapArraySize = UInt32(MemoryLayout<CFArray>.stride)
    
    let status = AudioObjectSetPropertyData(deviceID, &tapListAddress, 0, nil, tapArraySize, &tapArray)
    
    guard status == kAudioHardwareNoError else {
      print("❌ [AudioCaptureManager] Failed to add tap to aggregate device: \(status)")
      return false
    }
    
    print("✅ [AudioCaptureManager] Tap added to aggregate device")
    return true
  }
  
  /// Setup full system audio capture (all processes)
  /// - Parameter completion: Callback with device ID if successful
  func setupFullSystemCapture(completion: @escaping (AudioObjectID?) -> Void) {
    // 0. 이미 존재하는 aggregate device 찾기
    if let existingID = findExistingAggregateDevice() {
      print("♻️ Using existing aggregate device: \(existingID)")
      self.aggregateDeviceID = existingID
      completion(existingID)
      return
    }
    
    // 1. Get all audio processes
    let processList = getAllAudioProcesses()
    print("✅ [AudioCaptureManager] Found \(processList.count) audio processes")
    
    // 2. Create audio tap
    guard let tapID = createAudioTap(processes: processList) else {
      completion(nil)
      return
    }
    
    // 3. Create aggregate device
    guard let deviceID = createAggregateDevice() else {
      AudioHardwareDestroyProcessTap(tapID)
      completion(nil)
      return
    }
    
    // 4. Add tap to aggregate device
    guard addTapToAggregateDevice(tapID: tapID, deviceID: deviceID) else {
      AudioHardwareDestroyProcessTap(tapID)
      AudioHardwareDestroyAggregateDevice(deviceID)
      completion(nil)
      return
    }

    print("⏳ [AudioCaptureManager] Waiting for device to be ready...")
    // Give the aggregate device time to initialize (CoreAudio needs time)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      print("✅ [AudioCaptureManager] Full system audio capture ready! Device ID: \(deviceID)")
      completion(deviceID)
    }
  }
  
  func findExistingAggregateDevice() -> AudioObjectID? {
      var address = AudioObjectPropertyAddress(
          mSelector: kAudioHardwarePropertyDevices,
          mScope: kAudioObjectPropertyScopeGlobal,
          mElement: kAudioObjectPropertyElementMain
      )

      var propertySize: UInt32 = 0
      AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                     &address, 0, nil, &propertySize)

      let deviceCount = Int(propertySize) / MemoryLayout<AudioObjectID>.stride
      var devices = Array(repeating: AudioObjectID(0), count: deviceCount)

      AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                 &address, 0, nil, &propertySize, &devices)

      for dev in devices {
          var name: CFString = "" as CFString
          var nameSize = UInt32(MemoryLayout<CFString>.stride)

          var nameAddress = AudioObjectPropertyAddress(
              mSelector: kAudioObjectPropertyName,
              mScope: kAudioObjectPropertyScopeGlobal,
              mElement: kAudioObjectPropertyElementMain
          )

          let status = AudioObjectGetPropertyData(dev, &nameAddress, 0, nil, &nameSize, &name)

          if status == kAudioHardwareNoError,
             (name as String) == "Full System Audio Capture Device" {
              print("🔎 Found existing aggregate device: \(dev)")
              return dev
          }
      }

      return nil
  }
   
  /// Clean up created audio objects
  func cleanup() {
    if tapID != kAudioObjectUnknown {
      AudioHardwareDestroyProcessTap(tapID)
      print("🗑️ [AudioCaptureManager] Destroyed audio tap: \(tapID)")
      tapID = kAudioObjectUnknown
    }
    
//    if aggregateDeviceID != kAudioObjectUnknown {
//      AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
//      print("🗑️ [AudioCaptureManager] Destroyed aggregate device: \(aggregateDeviceID)")
//      aggregateDeviceID = kAudioObjectUnknown
//    }
  }
  
  deinit {
    cleanup()
  }
}
