//
//  STTTranscriberManager.swift
//  Openock
//
//  Created by JiJooMaeng on 10/26/25.
//

/*
 STT Transcriber Manager

 Abstract:
 Manages Speech-to-Text transcription using macOS 26's SpeechTranscriber API.
 Handles audio format conversion, analyzer pipeline, and transcript generation.
 */

import FoundationModels
import Foundation
import Speech
import AVFoundation
import Combine

class STTTranscriberManager: ObservableObject {

  @Published var transcript = ""
  @Published var errorMessage: String?
  @Published var detectedLanguage: String = "ko-KR"  // 현재 감지된 언어

  // Dual transcriber setup (Korean + English)
  private var koTranscriber: SpeechTranscriber?
  private var enTranscriber: SpeechTranscriber?
  private var koAnalyzer: SpeechAnalyzer?
  private var enAnalyzer: SpeechAnalyzer?
  private var koInputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var enInputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var analyzerFormat: AVAudioFormat?
  private var converter: AVAudioConverter?

  @Published var isTranscribing = false

  // Foundation Models for text improvement --------------------------------------------------------------
  private var enableAIImprovement = true
  private var debugMode = false  // 디버그 모드: STT 원본도 함께 표시


  private var recentContextSentences: [String] = []  // 최근 문장들 (맥락용)
  private let maxContextSentences = 5  // 최대 5개 문장 유지 (더 많은 맥락)

  // Language detection --------------------------------------------------------------
  private var languageDetectionEnabled = true  // 자동 언어 감지 활성화

  /// Start the transcription process
  @MainActor
  func startTranscription() async {
    print("🔄 [STTTranscriberManager] Starting dual-language transcription...")

    // ✅ Set isTranscribing early to accept incoming audio buffers
    isTranscribing = true

    // Create Korean SpeechTranscriber
    koTranscriber = SpeechTranscriber(
        locale: Locale(identifier: "ko-KR"),
        preset: .progressiveTranscription
    )
    print("✅ [STTTranscriberManager] Korean transcriber created")

    // Create English SpeechTranscriber
    enTranscriber = SpeechTranscriber(
        locale: Locale(identifier: "en-US"),
        preset: .progressiveTranscription
    )
    print("✅ [STTTranscriberManager] English transcriber created")

    guard let koTranscriber = koTranscriber, let enTranscriber = enTranscriber else {
      print("❌ [STTTranscriberManager] Failed to create transcribers")
      return
    }

    // Download assets for both languages
    if let koInstallRequest = try? await AssetInventory.assetInstallationRequest(supporting: [koTranscriber]) {
        try? await koInstallRequest.downloadAndInstall()
        print("✅ [STTTranscriberManager] Korean assets downloaded")
    }

    if let enInstallRequest = try? await AssetInventory.assetInstallationRequest(supporting: [enTranscriber]) {
        try? await enInstallRequest.downloadAndInstall()
        print("✅ [STTTranscriberManager] English assets downloaded")
    }

    // Initialize Foundation Models for AI text improvement
    if #available(macOS 15.1, *), enableAIImprovement {
      do {
        try await STTFoundationModels.shared.initialize()
        print("✅ [STTTranscriberManager] Foundation Models initialized for text improvement")
      } catch {
        print("⚠️ [STTTranscriberManager] Foundation Models initialization failed: \(error)")
        enableAIImprovement = false
      }
    }

    // Set up analyzer pipelines for both languages
    let koAnalyzer = SpeechAnalyzer(modules: [koTranscriber])
    let enAnalyzer = SpeechAnalyzer(modules: [enTranscriber])
    self.koAnalyzer = koAnalyzer
    self.enAnalyzer = enAnalyzer

    // Get best format compatible with both transcribers
    let bestFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [koTranscriber, enTranscriber])
    self.analyzerFormat = bestFormat

    if let bestFormat = bestFormat {
      print("✅ [STTTranscriberManager] Best analyzer format: \(bestFormat.sampleRate)Hz, \(bestFormat.channelCount) channels")
    } else {
      print("⚠️ [STTTranscriberManager] No best format available")
    }

    // Create AsyncStreams for both languages
    let (koInputSequence, koInputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
    let (enInputSequence, enInputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
    self.koInputContinuation = koInputBuilder
    self.enInputContinuation = enInputBuilder

    // Start both analyzers
    Task {
      print("🔄 [STTTranscriberManager] Starting Korean analyzer...")
      do {
        try await koAnalyzer.start(inputSequence: koInputSequence)
        print("✅ [STTTranscriberManager] Korean analyzer started")
      } catch {
        print("❌ [STTTranscriberManager] Korean analyzer start error: \(error)")
      }
    }

    Task {
      print("🔄 [STTTranscriberManager] Starting English analyzer...")
      do {
        try await enAnalyzer.start(inputSequence: enInputSequence)
        print("✅ [STTTranscriberManager] English analyzer started")
      } catch {
        print("❌ [STTTranscriberManager] English analyzer start error: \(error)")
      }
    }

    // Process transcription results from both transcribers in background
    Task {
      await processDualTranscriptionResults(koTranscriber: koTranscriber, enTranscriber: enTranscriber)
    }

    print("✅ [STTTranscriberManager] Dual-language transcription started (background processing)")
  }

  /// Process dual transcription results from both Korean and English transcribers
  @MainActor
  private func processDualTranscriptionResults(koTranscriber: SpeechTranscriber, enTranscriber: SpeechTranscriber) async {
    var finalized = AttributedString("")
    var volatile = AttributedString("")

    print("🔄 [STTTranscriberManager] Starting dual transcription result processing...")

    // Shared actor to coordinate results
    let resultCoordinator = ResultCoordinator()

    do {
      // Process both transcribers concurrently - event-driven
      await withTaskGroup(of: Void.self) { group in
        // Korean transcriber task - process immediately when result arrives
        group.addTask { @MainActor in
          do {
            for try await result in koTranscriber.results {
              print("🇰🇷 [Korean] Result - isFinal: \(result.isFinal), text: '\(String(result.text.characters))'")

              await resultCoordinator.updateKorean(text: result.text, isFinal: result.isFinal)

              // Immediately process
              if await self.processCombinedResults(
                coordinator: resultCoordinator,
                finalized: &finalized,
                volatile: &volatile
              ) {
                let newTranscript = String(finalized.characters) + String(volatile.characters)
                self.objectWillChange.send()
                self.transcript = newTranscript
              }
            }
          } catch {
            print("❌ [Korean] Transcription error: \(error)")
          }
        }

        // English transcriber task - process immediately when result arrives
        group.addTask { @MainActor in
          do {
            for try await result in enTranscriber.results {
              print("🇺🇸 [English] Result - isFinal: \(result.isFinal), text: '\(String(result.text.characters))'")

              await resultCoordinator.updateEnglish(text: result.text, isFinal: result.isFinal)

              // Immediately process
              if await self.processCombinedResults(
                coordinator: resultCoordinator,
                finalized: &finalized,
                volatile: &volatile
              ) {
                let newTranscript = String(finalized.characters) + String(volatile.characters)
                self.objectWillChange.send()
                self.transcript = newTranscript
              }
            }
          } catch {
            print("❌ [English] Transcription error: \(error)")
          }
        }
      }
    } catch {
      print("❌ Dual transcription error: \(error)")
      self.errorMessage = "전사 오류: \(error.localizedDescription)"
    }

    isTranscribing = false
  }

  /// Process combined results from both transcribers
  @MainActor
  private func processCombinedResults(
    coordinator: ResultCoordinator,
    finalized: inout AttributedString,
    volatile: inout AttributedString
  ) async -> Bool {
    let ko = await coordinator.korean
    let en = await coordinator.english

    guard let selectedResult = await selectBestResult(koResult: ko, enResult: en) else {
      return false
    }

    if selectedResult.isFinal {
      // Prevent duplicate final processing
      guard await coordinator.shouldProcessFinal() else {
        print("⏭️ Skipping duplicate final result")
        return false
      }
      let originalText = String(selectedResult.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
      let detectedLang = selectedResult.language

      print("🎯 [Selected \(detectedLang)] STT 원본: '\(originalText)'")
      self.detectedLanguage = detectedLang

      // AI improvement
      let rawImprovedText: String
      if #available(macOS 15.1, *), self.enableAIImprovement, !originalText.isEmpty {
        rawImprovedText = await self.withTimeout(seconds: 5) {
          do {
            let contextString = self.recentContextSentences.isEmpty ? nil : self.recentContextSentences.joined(separator: " ")
            return try await STTFoundationModels.shared.improveText(originalText, previousContext: contextString, language: detectedLang)
          } catch {
            print("⚠️ AI improvement failed: \(error)")
            return originalText
          }
        } ?? originalText
      } else {
        rawImprovedText = originalText
      }

      let improvedText = rawImprovedText.trimmingCharacters(in: .whitespacesAndNewlines)
      let hasChanged = originalText != improvedText

      if hasChanged {
        print("✨ AI 교정: '\(originalText)' → '\(improvedText)'")
      } else {
        print("✅ AI 판단: 수정 불필요")
      }

      // Display with language indicator
      if self.debugMode && hasChanged {
        finalized += AttributedString("[\(detectedLang == "ko-KR" ? "🇰🇷" : "🇺🇸") 원본: \(originalText)] \(improvedText)\n")
      } else {
        finalized += AttributedString(improvedText)
      }

      self.recentContextSentences.append(improvedText)
      if self.recentContextSentences.count > self.maxContextSentences {
        self.recentContextSentences.removeFirst()
      }

      volatile = AttributedString("")

      // Clear processed results
      await coordinator.clearBoth()

    } else {
      // Partial result
      volatile = selectedResult.text
      print("⏳ Partial (\(selectedResult.language)): '\(String(selectedResult.text.characters))'")
    }

    return true
  }

  // Result coordinator actor to safely share state between tasks
  actor ResultCoordinator {
    var korean: (text: AttributedString, isFinal: Bool)?
    var english: (text: AttributedString, isFinal: Bool)?
    private var lastProcessedFinalTimestamp: Date?
    private var processingFinal = false  // Prevent duplicate final processing

    func updateKorean(text: AttributedString, isFinal: Bool) {
      korean = (text: text, isFinal: isFinal)
    }

    func updateEnglish(text: AttributedString, isFinal: Bool) {
      english = (text: text, isFinal: isFinal)
    }

    func shouldProcessFinal() -> Bool {
      // If already processing a final result, skip
      if processingFinal {
        return false
      }

      // Check if either has a final result
      let koFinal = korean?.isFinal ?? false
      let enFinal = english?.isFinal ?? false

      if koFinal || enFinal {
        processingFinal = true
        return true
      }

      return false
    }

    func clearBoth() {
      korean = nil
      english = nil
      processingFinal = false
      lastProcessedFinalTimestamp = Date()
    }
  }

  /// Select best result between Korean and English transcriptions
  private func selectBestResult(koResult: (text: AttributedString, isFinal: Bool)?, enResult: (text: AttributedString, isFinal: Bool)?) -> (text: AttributedString, isFinal: Bool, language: String)? {
    guard languageDetectionEnabled else {
      // If detection disabled, prefer Korean
      if let ko = koResult {
        return (ko.text, ko.isFinal, "ko-KR")
      }
      return nil
    }

    // If only one has result, use that
    if koResult == nil, let en = enResult {
      return (en.text, en.isFinal, "en-US")
    }
    if let ko = koResult, enResult == nil {
      return (ko.text, ko.isFinal, "ko-KR")
    }

    guard let ko = koResult, let en = enResult else {
      return nil
    }

    let koText = String(ko.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    let enText = String(en.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)

    // If one is empty, use the other
    if koText.isEmpty && !enText.isEmpty {
      return (en.text, en.isFinal, "en-US")
    }
    if !koText.isEmpty && enText.isEmpty {
      return (ko.text, ko.isFinal, "ko-KR")
    }

    // Both have text - compare by length (longer usually means more confident)
    let koLength = koText.count
    let enLength = enText.count

    // If one is significantly longer (>30% difference), prefer that
    let lengthRatio = Double(max(koLength, enLength)) / Double(max(min(koLength, enLength), 1))

    if lengthRatio > 1.3 {
      if koLength > enLength {
        print("🎯 [Detection] Selected Korean (length: \(koLength) vs \(enLength))")
        return (ko.text, ko.isFinal, "ko-KR")
      } else {
        print("🎯 [Detection] Selected English (length: \(enLength) vs \(koLength))")
        return (en.text, en.isFinal, "en-US")
      }
    }

    // If lengths similar, use heuristic: check for ASCII/Korean characters
    let koHasKorean = koText.contains(where: { char in
      let scalar = char.unicodeScalars.first
      return scalar.map { (0xAC00...0xD7A3).contains($0.value) } ?? false
    })

    let enHasKorean = enText.contains(where: { char in
      let scalar = char.unicodeScalars.first
      return scalar.map { (0xAC00...0xD7A3).contains($0.value) } ?? false
    })

    // Prefer Korean transcriber if Korean characters detected in either
    if koHasKorean {
      print("🎯 [Detection] Selected Korean (Korean chars detected)")
      return (ko.text, ko.isFinal, "ko-KR")
    }

    // Otherwise prefer English
    print("🎯 [Detection] Selected English (no Korean chars)")
    return (en.text, en.isFinal, "en-US")
  }

  /// Process transcription results from SpeechTranscriber (legacy, kept for reference)
  @MainActor
  private func processTranscriptionResults(transcriber: SpeechTranscriber) async {
    var finalized = AttributedString("")
    var volatile = AttributedString("")

    print("🔄 [STTTranscriberManager] Waiting for transcription results...")
    var resultCount = 0

    do {
      for try await result in transcriber.results {
        resultCount += 1
        print("📝 [STTTranscriberManager] Result #\(resultCount) - isFinal: \(result.isFinal), text length: \(result.text.characters.count)")

        if result.isFinal {
          let originalText = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)

          // 디버그: 원본 STT 결과 출력
          print("🎤 [STTTranscriberManager] STT 원본: '\(originalText)'")

          // Foundation Models로 텍스트 개선 (타임아웃 처리)
          let rawImprovedText: String
          if #available(macOS 15.1, *), enableAIImprovement, !originalText.isEmpty {
            // 타임아웃 5초 설정
            rawImprovedText = await withTimeout(seconds: 5) {
              do {
                // 최근 5문장의 맥락을 전달
                let contextString = self.recentContextSentences.isEmpty ? nil : self.recentContextSentences.joined(separator: " ")

                let result = try await STTFoundationModels.shared.improveText(
                  originalText,
                  previousContext: contextString
                )

                return result
              } catch {
                print("⚠️ [STTTranscriberManager] AI improvement failed: \(error)")
                return originalText
              }
            } ?? originalText  // 타임아웃 시 원본 사용
          } else {
            rawImprovedText = originalText
            print("⏭️ [STTTranscriberManager] AI 교정 비활성화됨")
          }

          // Normalize: trim & remove extra spaces for comparison
          let improvedText = rawImprovedText.trimmingCharacters(in: .whitespacesAndNewlines)
          let normalizedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
          let normalizedImproved = improvedText.trimmingCharacters(in: .whitespacesAndNewlines)

          // Check if actually changed
          let hasChanged = normalizedOriginal != normalizedImproved

          // 변경 사항 표시
          if hasChanged {
            print("✨ [STTTranscriberManager] AI 교정: '\(originalText)' → '\(improvedText)'")
          } else {
            print("✅ [STTTranscriberManager] AI 판단: 수정 불필요")
          }

          // 디버그 모드: 원본과 개선본을 함께 표시
          if debugMode && hasChanged {
            finalized += AttributedString("[원본: \(originalText)] \(improvedText)\n")
          } else {
            finalized += AttributedString(improvedText)
          }

          // 최근 맥락 업데이트 (최대 5문장)
          recentContextSentences.append(improvedText)
          if recentContextSentences.count > maxContextSentences {
            recentContextSentences.removeFirst()
          }

          volatile = AttributedString("")
          print("📝 [STTTranscriberManager] 최종 출력: '\(improvedText)'")
        } else {
          // Partial 결과는 그대로 표시 (실시간성 유지)
          volatile = result.text
          print("⏳ [STTTranscriberManager] Partial text: '\(String(result.text.characters))'")
        }

        let newTranscript = String(finalized.characters) + String(volatile.characters)
        self.objectWillChange.send()
        self.transcript = newTranscript
        print("✅ [STTTranscriberManager] Transcript updated (length \(newTranscript.count))")
      }
      print("⚠️ [STTTranscriberManager] Transcription loop ended")
    } catch {
      print("❌ [STTTranscriberManager] Transcription error: \(error.localizedDescription)")
      self.objectWillChange.send()
      self.errorMessage = "전사 오류: \(error.localizedDescription)"
    }

    isTranscribing = false
  }

  /// Process audio buffer and send to transcriber
  func processAudio(buffer: AVAudioPCMBuffer) {
    guard isTranscribing else {
      print("⚠️ [STTTranscriberManager] Not transcribing, ignoring buffer")
      return
    }

    guard let analyzerFormat = analyzerFormat else {
      print("⚠️ [STTTranscriberManager] No analyzer format, ignoring buffer")
      return
    }

    print("🎤 [STTTranscriberManager] Received audio buffer: \(buffer.frameLength) frames at \(buffer.format.sampleRate)Hz, \(buffer.format.channelCount) channels")

    // Convert format if needed
    let sendBuffer: AVAudioPCMBuffer

    let needsConversion = buffer.format.sampleRate != analyzerFormat.sampleRate ||
                         buffer.format.channelCount != analyzerFormat.channelCount

    if needsConversion {
      print("🔄 [STTTranscriberManager] Converting from \(buffer.format.sampleRate)Hz/\(buffer.format.channelCount)ch to \(analyzerFormat.sampleRate)Hz/\(analyzerFormat.channelCount)ch")

      if converter == nil || converter?.inputFormat != buffer.format || converter?.outputFormat != analyzerFormat {
        converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
        converter?.primeMethod = .none
        print("✅ [STTTranscriberManager] Created new converter")
      }

      guard let converter = converter else {
        print("❌ [STTTranscriberManager] Failed to create converter")
        return
      }

      // Calculate output frame capacity
      let outputFrameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * analyzerFormat.sampleRate / buffer.format.sampleRate))

      guard let out = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: outputFrameCapacity) else {
        print("❌ [STTTranscriberManager] Failed to create output buffer")
        return
      }

      var err: NSError?
      let status = converter.convert(to: out, error: &err) { _, inStatus in
        inStatus.pointee = .haveData
        return buffer
      }

      if let err = err {
        print("❌ [STTTranscriberManager] AVAudioConverter error: \(err)")
        return
      }

      if status == .error {
        print("❌ [STTTranscriberManager] Conversion failed with error status")
        return
      }

      // Verify frameLength
      guard out.frameLength > 0 else {
        print("❌ [STTTranscriberManager] Converted buffer has zero frames")
        return
      }

      print("✅ [STTTranscriberManager] Converted successfully: \(out.frameLength) frames")
      sendBuffer = out
    } else {
      print("✅ [STTTranscriberManager] No conversion needed, using original buffer")
      sendBuffer = buffer
    }

    // Send to both analyzers
    koInputContinuation?.yield(AnalyzerInput(buffer: sendBuffer))
    enInputContinuation?.yield(AnalyzerInput(buffer: sendBuffer))
    print("✅ [STTTranscriberManager] Audio buffer sent to both analyzers (\(sendBuffer.frameLength) frames)")
  }

  /// Stop transcription
  func stopTranscription() {
    print("🛑 [STTTranscriberManager] Stopping dual transcription...")

    // Finish both input streams
    koInputContinuation?.finish()
    enInputContinuation?.finish()

    // Clear all resources
    koInputContinuation = nil
    enInputContinuation = nil
    koAnalyzer = nil
    enAnalyzer = nil
    analyzerFormat = nil
    converter = nil
    koTranscriber = nil
    enTranscriber = nil
    isTranscribing = false
    recentContextSentences.removeAll()

    // Cleanup Foundation Models
    if #available(macOS 15.1, *) {
      STTFoundationModels.shared.cleanup()
    }

    print("✅ [STTTranscriberManager] Dual transcription stopped")
  }

  /// Clear transcript
  func clearTranscript() {
    transcript = ""
    errorMessage = nil
    recentContextSentences.removeAll()
  }

  /// AI 텍스트 개선 기능 켜기/끄기
  func setAIImprovement(enabled: Bool) {
    enableAIImprovement = enabled
    print("🔧 [STTTranscriberManager] AI improvement \(enabled ? "enabled" : "disabled")")
  }

  /// 디버그 모드 켜기/끄기
  func setDebugMode(enabled: Bool) {
    debugMode = enabled
    print("🔧 [STTTranscriberManager] Debug mode \(enabled ? "enabled" : "disabled")")
  }

  /// 자동 언어 감지 켜기/끄기
  func setLanguageDetection(enabled: Bool) {
    languageDetectionEnabled = enabled
    print("🔧 [STTTranscriberManager] Language detection \(enabled ? "enabled (auto)" : "disabled (Korean only)")")
  }

  deinit {
    stopTranscription()
  }

  /// Timeout helper
  private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
      group.addTask {
        await operation()
      }

      group.addTask {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return nil
      }

      let result = await group.next()
      group.cancelAll()
      return result ?? nil
    }
  }
}
