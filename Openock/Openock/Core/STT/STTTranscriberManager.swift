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

  private var transcriber: SpeechTranscriber?
  private var analyzer: SpeechAnalyzer?
  private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var analyzerFormat: AVAudioFormat?
  private var converter: AVAudioConverter?

  @Published var isTranscribing = false

  // Foundation Models for text improvement
  private var enableAIImprovement = true
  private var debugMode = true  // 디버그 모드: STT 원본도 함께 표시
  private var recentContextSentences: [String] = []  // 최근 문장들 (맥락용)
  private let maxContextSentences = 5  // 최대 5개 문장 유지 (더 많은 맥락)

  /// Start the transcription process
  @MainActor
  func startTranscription() async {
    print("🔄 [STTTranscriberManager] Starting transcription...")

    // Create SpeechTranscriber
    transcriber = SpeechTranscriber(
        locale: Locale(identifier: "ko-KR"),
        preset: .progressiveTranscription
    )
    print("✅ [STTTranscriberManager] SpeechTranscriber created")

    guard let transcriber = transcriber else {
      print("❌ [STTTranscriberManager] No transcriber available")
      return
    }

    // Assets
    if let installationRequest = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try? await installationRequest.downloadAndInstall()
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

    // Set up analyzer pipeline
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    self.analyzer = analyzer

    let bestFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    self.analyzerFormat = bestFormat

    if let bestFormat = bestFormat {
      print("✅ [STTTranscriberManager] Best analyzer format: \(bestFormat.sampleRate)Hz, \(bestFormat.channelCount) channels")
    } else {
      print("⚠️ [STTTranscriberManager] No best format available")
    }

    // Create AsyncStream
    let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
    self.inputContinuation = inputBuilder

    // Start analyzer
    Task {
      print("🔄 [STTTranscriberManager] Starting analyzer...")
      do {
        try await analyzer.start(inputSequence: inputSequence)
        print("✅ [STTTranscriberManager] Analyzer started")
      } catch {
        print("❌ [STTTranscriberManager] Analyzer start error: \(error)")
      }
    }

    // Process transcription results in background
    isTranscribing = true
    Task {
      await processTranscriptionResults(transcriber: transcriber)
    }

    print("✅ [STTTranscriberManager] Transcription started (background processing)")
  }

  /// Process transcription results from SpeechTranscriber
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
          let originalText = String(result.text.characters)

          // 디버그: 원본 STT 결과 출력
          print("🎤 [STTTranscriberManager] STT 원본: '\(originalText)'")

          // Foundation Models로 텍스트 개선 (타임아웃 처리)
          let improvedText: String
          if #available(macOS 15.1, *), enableAIImprovement, !originalText.isEmpty {
            // 타임아웃 5초 설정
            improvedText = await withTimeout(seconds: 5) {
              do {
                // 최근 5문장의 맥락을 전달
                let contextString = self.recentContextSentences.isEmpty ? nil : self.recentContextSentences.joined(separator: " ")

                let result = try await STTFoundationModels.shared.improveText(
                  originalText,
                  previousContext: contextString
                )

                // 변경 사항 표시
                if result != originalText {
                  print("✨ [STTTranscriberManager] AI 교정: '\(originalText)' → '\(result)'")
                } else {
                  print("✅ [STTTranscriberManager] AI 판단: 수정 불필요")
                }
                return result
              } catch {
                print("⚠️ [STTTranscriberManager] AI improvement failed: \(error)")
                return originalText
              }
            } ?? originalText  // 타임아웃 시 원본 사용
          } else {
            improvedText = originalText
            print("⏭️ [STTTranscriberManager] AI 교정 비활성화됨")
          }

          // 디버그 모드: 원본과 개선본을 함께 표시
          if debugMode && improvedText != originalText {
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

    // Send to analyzer
    inputContinuation?.yield(AnalyzerInput(buffer: sendBuffer))
    print("✅ [STTTranscriberManager] Audio buffer sent to analyzer (\(sendBuffer.frameLength) frames)")
  }

  /// Stop transcription
  func stopTranscription() {
    print("🛑 [STTTranscriberManager] Stopping transcription...")

    inputContinuation?.finish()
    inputContinuation = nil
    analyzer = nil
    analyzerFormat = nil
    converter = nil
    transcriber = nil
    isTranscribing = false
    recentContextSentences.removeAll()

    // Cleanup Foundation Models
    if #available(macOS 15.1, *) {
      STTFoundationModels.shared.cleanup()
    }

    print("✅ [STTTranscriberManager] Transcription stopped")
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
