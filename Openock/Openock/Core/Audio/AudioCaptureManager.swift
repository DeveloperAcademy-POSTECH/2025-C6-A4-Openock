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

  var tapID: AudioObjectID = kAudioObjectUnknown
  var aggregateDeviceID: AudioObjectID = kAudioObjectUnknown

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

    // Check current taps before adding
    let tapsBefore = getTapsFromAggregateDevice(deviceID: deviceID)
    print("📋 [AudioCaptureManager] Taps before adding: \(tapsBefore)")

    // Get tap UID
    var tapUIDAddress = AudioObjectPropertyAddress(
      mSelector: kAudioTapPropertyUID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var tapUID: CFString = "" as CFString
    var tapUIDSize = UInt32(MemoryLayout<CFString>.stride)
    _ = withUnsafeMutableBytes(of: &tapUID) { pointer in
        AudioObjectGetPropertyData(tapID, &tapUIDAddress, 0, nil, &tapUIDSize, pointer.baseAddress!)
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

    let status = withUnsafeBytes(of: &tapArray) { pointer in
        AudioObjectSetPropertyData(deviceID, &tapListAddress, 0, nil, UInt32(pointer.count), pointer.baseAddress!)
    }

    guard status == kAudioHardwareNoError else {
      print("❌ [AudioCaptureManager] Failed to add tap to aggregate device: \(status)")
      return false
    }

    // Check taps after adding
    let tapsAfter = getTapsFromAggregateDevice(deviceID: deviceID)
    print("✅ [AudioCaptureManager] Tap added to aggregate device. Taps after: \(tapsAfter)")
    return true
  }

  /// Refresh the audio tap with all current processes
  func refreshAudioTap() {
    print("🔄 [AudioCaptureManager] Refreshing audio tap...")

    guard aggregateDeviceID != kAudioObjectUnknown else {
      print("❌ [AudioCaptureManager] No aggregate device to update")
      return
    }

    // Step 1: Remove ALL taps from aggregate device first (this clears the list)
    print("🗑️ [AudioCaptureManager] Clearing tap list from aggregate device...")
    let removalSuccess = removeTapFromAggregateDevice(deviceID: aggregateDeviceID)

    if !removalSuccess {
      print("⚠️ [AudioCaptureManager] Tap removal failed, but continuing...")
    }

    // Step 2: Destroy old tap object
    if tapID != kAudioObjectUnknown {
      let destroyStatus = AudioHardwareDestroyProcessTap(tapID)
      if destroyStatus == noErr {
        print("✅ [AudioCaptureManager] Destroyed old tap: \(tapID)")
      } else {
        print("❌ [AudioCaptureManager] Failed to destroy old tap \(tapID): \(destroyStatus)")
      }
      tapID = kAudioObjectUnknown
    }

    // Step 3: Get all current processes
    let processList = getAllAudioProcesses()
    print("✅ [AudioCaptureManager] Found \(processList.count) audio processes")

    // Step 4: Create new tap
    guard let newTapID = createAudioTap(processes: processList) else {
      print("❌ [AudioCaptureManager] Failed to refresh tap")
      return
    }

    // Step 5: Add new tap to aggregate device
    guard addTapToAggregateDevice(tapID: newTapID, deviceID: aggregateDeviceID) else {
      print("❌ [AudioCaptureManager] Failed to add new tap to device")
      AudioHardwareDestroyProcessTap(newTapID)
      return
    }

    print("✅ [AudioCaptureManager] Audio tap refreshed successfully")
  }

  /// Setup full system audio capture (all processes)
  /// - Parameter completion: Callback with device ID if successful
  func setupFullSystemCapture(completion: @escaping (AudioObjectID?) -> Void) {
    // 0. Clean up any existing taps and aggregate device from previous sessions
    cleanupExistingTaps()

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

  deinit {
    cleanup()
  }
}
