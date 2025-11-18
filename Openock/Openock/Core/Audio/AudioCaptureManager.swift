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
  private var monitoringTimer: Timer?
  private var lastProcessCount: Int = 0

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

  /// Find tap ID by its UID
  private func findTapByUID(_ uid: String) -> AudioObjectID? {
    print("🔍 [AudioCaptureManager] Searching for tap with UID: \(uid)")

    // Get all audio objects and search for the tap with matching UID
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var propertySize: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)

    let deviceCount = Int(propertySize) / MemoryLayout<AudioObjectID>.stride
    var devices = Array(repeating: AudioObjectID(0), count: deviceCount)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &devices)

    print("🔍 [AudioCaptureManager] Searching through \(deviceCount) audio devices/taps")

    // Search through all devices/taps
    for deviceID in devices {
      // Try kAudioTapPropertyUID first (for taps)
      var tapUIDAddress = AudioObjectPropertyAddress(
        mSelector: kAudioTapPropertyUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )

      var tapUID: CFString = "" as CFString
      var tapUIDSize = UInt32(MemoryLayout<CFString>.stride)
      var status = AudioObjectGetPropertyData(deviceID, &tapUIDAddress, 0, nil, &tapUIDSize, &tapUID)

      if status == kAudioHardwareNoError {
        let tapUIDString = tapUID as String
        print("   Found tap \(deviceID) with UID: \(tapUIDString)")
        if tapUIDString == uid {
          print("✅ [AudioCaptureManager] Found matching tap: \(deviceID)")
          return deviceID
        }
      }

      // Fallback to kAudioDevicePropertyDeviceUID
      var deviceUIDAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )

      var deviceUID: CFString = "" as CFString
      var uidSize = UInt32(MemoryLayout<CFString>.stride)
      status = AudioObjectGetPropertyData(deviceID, &deviceUIDAddress, 0, nil, &uidSize, &deviceUID)

      if status == kAudioHardwareNoError {
        let deviceUIDString = deviceUID as String
        if deviceUIDString == uid {
          print("✅ [AudioCaptureManager] Found matching device: \(deviceID)")
          return deviceID
        }
      }
    }

    print("❌ [AudioCaptureManager] Could not find tap/device with UID: \(uid)")
    return nil
  }

  /// Clean up existing aggregate device's taps
  func cleanupExistingTaps() {
    print("🧹 [AudioCaptureManager] Cleaning up existing taps...")
    // First, clean up any orphan tap process objects from previous runs
    cleanupOrphanProcessTaps()

    // Find existing aggregate device
    if let existingID = findExistingAggregateDevice() {
      print("🔍 [AudioCaptureManager] Found existing aggregate device: \(existingID)")

      // Get all tap UIDs from the device (before mutating the tap list)
      let tapUIDs = getTapsFromAggregateDevice(deviceID: existingID)
      print("📋 [AudioCaptureManager] Found \(tapUIDs.count) taps to destroy")

      // Destroy each tap
      for tapUID in tapUIDs {
        if let tapID = findTapByUID(tapUID) {
          let status = AudioHardwareDestroyProcessTap(tapID)
          if status == noErr {
            print("✅ [AudioCaptureManager] Destroyed tap: \(tapID) (\(tapUID))")
          } else {
            print("❌ [AudioCaptureManager] Failed to destroy tap \(tapID): \(status)")
          }
        } else {
          print("⚠️ [AudioCaptureManager] Could not find tap ID for UID: \(tapUID)")
        }
      }

      // Now clear the tap list on the aggregate device so Audio MIDI Setup UI updates as well
      _ = removeTapFromAggregateDevice(deviceID: existingID)

      // Destroy the aggregate device completely to clean up everything
      let destroyStatus = AudioHardwareDestroyAggregateDevice(existingID)
      if destroyStatus == noErr {
        print("✅ [AudioCaptureManager] Destroyed existing aggregate device: \(existingID)")
      } else {
        print("❌ [AudioCaptureManager] Failed to destroy aggregate device \(existingID): \(destroyStatus)")
      }
    } else {
      print("ℹ️ [AudioCaptureManager] No existing aggregate device to clean up")
    }
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
    var tapArraySize = UInt32(MemoryLayout<CFArray>.stride)

    let status = AudioObjectSetPropertyData(deviceID, &tapListAddress, 0, nil, tapArraySize, &tapArray)

    guard status == kAudioHardwareNoError else {
      print("❌ [AudioCaptureManager] Failed to add tap to aggregate device: \(status)")
      return false
    }

    // Check taps after adding
    let tapsAfter = getTapsFromAggregateDevice(deviceID: deviceID)
    print("✅ [AudioCaptureManager] Tap added to aggregate device. Taps after: \(tapsAfter)")
    return true
  }

  /// Get current taps from aggregate device
  private func getTapsFromAggregateDevice(deviceID: AudioObjectID) -> [String] {
    var tapListAddress = AudioObjectPropertyAddress(
      mSelector: kAudioAggregateDevicePropertyTapList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var propertySize: UInt32 = 0
    let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &tapListAddress, 0, nil, &propertySize)

    guard sizeStatus == kAudioHardwareNoError, propertySize > 0 else {
      return []
    }

    var tapArray: CFArray?
    var arraySize = propertySize
    let status = AudioObjectGetPropertyData(deviceID, &tapListAddress, 0, nil, &arraySize, &tapArray)

    guard status == kAudioHardwareNoError, let taps = tapArray as? [String] else {
      return []
    }

    return taps
  }
  /// Clean up any orphan process taps named "Full System Audio Tap"
  private func cleanupOrphanProcessTaps() {
    print("🧹 [AudioCaptureManager] Cleaning up orphan process taps...")

    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var propertySize: UInt32 = 0
    let sizeStatus = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)

    guard sizeStatus == kAudioHardwareNoError, propertySize > 0 else {
      print("ℹ️ [AudioCaptureManager] No process objects to clean up")
      return
    }

    let objectCount = Int(propertySize) / MemoryLayout<AudioObjectID>.stride
    var objects = Array(repeating: AudioObjectID(0), count: objectCount)

    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &objects)

    guard status == kAudioHardwareNoError else {
      print("❌ [AudioCaptureManager] Failed to get process object list: \(status)")
      return
    }

    print("🔍 [AudioCaptureManager] Scanning \(objectCount) process objects for orphan taps...")

    for objID in objects {
      var nameAddress = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )

      var name: CFString = "" as CFString
      var nameSize = UInt32(MemoryLayout<CFString>.stride)
      let nameStatus = AudioObjectGetPropertyData(objID, &nameAddress, 0, nil, &nameSize, &name)

      guard nameStatus == kAudioHardwareNoError else {
        continue
      }

      let nameString = name as String

      // Our taps are created with this name in createAudioTap()
      if nameString == "Full System Audio Tap" {
        let destroyStatus = AudioHardwareDestroyProcessTap(objID)
        if destroyStatus == noErr {
          print("✅ [AudioCaptureManager] Destroyed orphan tap process object: \(objID)")
        } else {
          print("❌ [AudioCaptureManager] Failed to destroy orphan tap \(objID): \(destroyStatus)")
        }
      }
    }
  }

  /// Remove all taps from an aggregate device
  /// - Parameter deviceID: The aggregate device ID
  /// - Returns: True if successful
  @discardableResult
  private func removeTapFromAggregateDevice(deviceID: AudioObjectID) -> Bool {
    print("🗑️ [AudioCaptureManager] Removing taps from aggregate device \(deviceID)...")

    // First check what taps are currently in the device
    let currentTaps = getTapsFromAggregateDevice(deviceID: deviceID)
    print("📋 [AudioCaptureManager] Current taps in device before removal: \(currentTaps)")

    if currentTaps.isEmpty {
      print("ℹ️ [AudioCaptureManager] No taps to remove")
      return true
    }

    var tapListAddress = AudioObjectPropertyAddress(
      mSelector: kAudioAggregateDevicePropertyTapList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    // Set empty array to remove all taps
    var emptyArray = [] as CFArray
    var arraySize = UInt32(MemoryLayout<CFArray>.stride)

    let status = AudioObjectSetPropertyData(deviceID, &tapListAddress, 0, nil, arraySize, &emptyArray)

    guard status == kAudioHardwareNoError else {
      print("❌ [AudioCaptureManager] Failed to remove taps from aggregate device: \(status)")
      return false
    }

    // Verify taps were actually removed
    let tapsAfterRemoval = getTapsFromAggregateDevice(deviceID: deviceID)
    print("📋 [AudioCaptureManager] Taps after removal: \(tapsAfterRemoval)")

    if tapsAfterRemoval.isEmpty {
      print("✅ [AudioCaptureManager] All taps successfully removed from aggregate device")
    } else {
      print("⚠️ [AudioCaptureManager] Warning: \(tapsAfterRemoval.count) taps still remain after removal!")
    }

    return true
  }
  
  /// Start monitoring for new audio processes
  private func startMonitoring() {
    // Get initial process count
    lastProcessCount = getAllAudioProcesses().count
    print("✅ [AudioCaptureManager] Started monitoring (initial process count: \(lastProcessCount))")

    // Check for new processes every 2 seconds
    monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      self?.checkForNewProcesses()
    }
  }

  /// Stop monitoring
  private func stopMonitoring() {
    monitoringTimer?.invalidate()
    monitoringTimer = nil
    print("🛑 [AudioCaptureManager] Stopped monitoring")
  }

  /// Check if new processes have been added
  private func checkForNewProcesses() {
    let currentProcessCount = getAllAudioProcesses().count

    if currentProcessCount != lastProcessCount {
      print("🔔 [AudioCaptureManager] Process count changed: \(lastProcessCount) → \(currentProcessCount)")
      lastProcessCount = currentProcessCount
      refreshAudioTap()
    }
  }

  /// Refresh the audio tap with all current processes
  private func refreshAudioTap() {
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
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      print("✅ [AudioCaptureManager] Full system audio capture ready! Device ID: \(deviceID)")

      // Start monitoring for new processes
      self?.startMonitoring()

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
    print("🧹 [AudioCaptureManager] Starting cleanup...")

    stopMonitoring()
    // Also proactively clean up any orphan process taps this run may have created
    cleanupOrphanProcessTaps()

    if tapID != kAudioObjectUnknown {
      let currentTapID = tapID
      let status = AudioHardwareDestroyProcessTap(tapID)
      if status == noErr {
        print("✅ [AudioCaptureManager] Successfully destroyed audio tap: \(currentTapID)")
      } else {
        print("❌ [AudioCaptureManager] Failed to destroy audio tap: \(currentTapID), status: \(status)")
      }
      tapID = kAudioObjectUnknown
    } else {
      print("ℹ️ [AudioCaptureManager] No tap to clean up")
    }

    if aggregateDeviceID != kAudioObjectUnknown {
      let currentAggregateID = aggregateDeviceID

      // aggregate device에 남아 있는 tap 리스트를 먼저 비운다.
      _ = removeTapFromAggregateDevice(deviceID: currentAggregateID)

      let status = AudioHardwareDestroyAggregateDevice(currentAggregateID)
      if status == noErr {
        print("🗑️ [AudioCaptureManager] Destroyed aggregate device: \(currentAggregateID)")
      } else {
        print("❌ [AudioCaptureManager] Failed to destroy aggregate device: \(currentAggregateID), status: \(status)")
      }

      aggregateDeviceID = kAudioObjectUnknown
    }

    print("✅ [AudioCaptureManager] Cleanup completed")
  }
  
  deinit {
    cleanup()
  }
}
