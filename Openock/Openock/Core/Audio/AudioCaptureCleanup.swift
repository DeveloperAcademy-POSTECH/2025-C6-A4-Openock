//
//  AudioCaptureCleanup.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

/*
 Audio Capture Cleanup Extension

 Abstract:
 Handles cleanup operations for AudioCaptureManager including:
 - Finding and destroying existing taps and aggregate devices
 - CoreAudio daemon restart
 - Orphan process cleanup
 */

import Foundation
import CoreAudio

extension AudioCaptureManager {

  // MARK: - Cleanup Operations

  /// Clean up existing aggregate device's taps
  func cleanupExistingTaps() {
    print("🧹 [AudioCaptureManager] Cleaning up existing taps...")
    // First, clean up any orphan tap process objects from previous runs
    cleanupOrphanProcessTaps()

    // Find all existing aggregate devices we created
    let existingDevices = findAllAggregateDevices()

    if existingDevices.isEmpty {
      print("ℹ️ [AudioCaptureManager] No existing aggregate device to clean up")
    } else {
      print("🔍 [AudioCaptureManager] Found \(existingDevices.count) aggregate device(s) to clean up: \(existingDevices)")

      for existingID in existingDevices {
        print("🔍 [AudioCaptureManager] Cleaning aggregate device: \(existingID)")

        // Get all tap UIDs from the device (before mutating the tap list)
        let tapUIDs = getTapsFromAggregateDevice(deviceID: existingID)
        print("📋 [AudioCaptureManager] Found \(tapUIDs.count) taps to destroy on device \(existingID)")

        // Destroy each tap if we can still find it
        for tapUID in tapUIDs {
          if let tapID = findTapByUID(tapUID) {
            let status = AudioHardwareDestroyProcessTap(tapID)
            if status == noErr {
              print("✅ [AudioCaptureManager] Destroyed tap: \(tapID) (\(tapUID))")
            } else {
              print("❌ [AudioCaptureManager] Failed to destroy tap \(tapID): \(status)")
            }
          } else {
            print("⚠️ [AudioCaptureManager] Could not find tap ID for UID: \(tapUID) on device \(existingID)")
          }
        }

        // Clear the tap list on this aggregate device so Audio MIDI Setup UI updates as well
        _ = removeTapFromAggregateDevice(deviceID: existingID)

        // Destroy the aggregate device completely to clean up everything
        let destroyStatus = AudioHardwareDestroyAggregateDevice(existingID)
        if destroyStatus == noErr {
          print("✅ [AudioCaptureManager] Destroyed existing aggregate device: \(existingID)")
        } else {
          print("❌ [AudioCaptureManager] Failed to destroy aggregate device \(existingID): \(destroyStatus)")
        }
      }
    }
  }

  /// Clean up any orphan process taps named "Full System Audio Tap"
  func cleanupOrphanProcessTaps() {
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

  // MARK: - Device Finding

  /// Find all existing aggregate devices created by Openock
  func findAllAggregateDevices() -> [AudioObjectID] {
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

    var result: [AudioObjectID] = []

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
        result.append(dev)
      }
    }

    return result
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

  /// Find tap ID by its UID
  func findTapByUID(_ uid: String) -> AudioObjectID? {
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

  // MARK: - Tap Management

  /// Get current taps from aggregate device
  func getTapsFromAggregateDevice(deviceID: AudioObjectID) -> [String] {
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

  /// Remove all taps from an aggregate device
  /// - Parameter deviceID: The aggregate device ID
  /// - Returns: True if successful
  @discardableResult
  func removeTapFromAggregateDevice(deviceID: AudioObjectID) -> Bool {
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
}
