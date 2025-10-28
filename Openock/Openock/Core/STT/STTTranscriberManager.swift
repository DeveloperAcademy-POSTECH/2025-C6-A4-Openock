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

@available(macOS 15.0, *)
class STTTranscriberManager: ObservableObject {
  
  @Published var transcript = ""
  @Published var errorMessage: String?
  
  private var transcriber: SpeechTranscriber?
  private var analyzer: SpeechAnalyzer?
  private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var analyzerFormat: AVAudioFormat?
  private var converter: AVAudioConverter?
  private var isTranscribing = false
  
  /// Start the transcription process
  @MainActor
  func startTranscription() async {
    print("🔄 [STTTranscriberManager] Starting transcription...")
    
    // Create SpeechTranscriber
//    let preset = SpeechTranscriber.Preset.progressiveTranscription
//    let transcriber = SpeechTranscriber(
//        locale: Locale(identifier: "ko-KR"),
//        transcriptionOptions: preset.transcriptionOptions,
//        reportingOptions: preset.reportingOptions.union([.alternativeTranscriptions]),
//        attributeOptions: preset.attributeOptions
//    )
    transcriber = SpeechTranscriber(locale: Locale(identifier: "ko-KR"), preset: .transcriptionWithAlternatives)
    print("✅ [STTTranscriberManager] SpeechTranscriber created")
    
    guard let transcriber = transcriber else {
      print("❌ [STTTranscriberManager] No transcriber available")
      return
    }
    
    // Assets
    if let installationRequest = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        try? await installationRequest.downloadAndInstall()
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
    
    // Process transcription results
    isTranscribing = true
    await processTranscriptionResults(transcriber: transcriber)
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
          finalized += result.text
          volatile = AttributedString("")
          print("✅ [STTTranscriberManager] Final text: '\(String(result.text.characters))'")
        } else {
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
    guard isTranscribing, let analyzerFormat = analyzerFormat else {
      return
    }
    
    // Convert format if needed
    let sendBuffer: AVAudioPCMBuffer
    if buffer.format != analyzerFormat {
      if converter == nil || converter?.inputFormat != buffer.format || converter?.outputFormat != analyzerFormat {
        converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
        converter?.primeMethod = .none
      }
      
      guard let converter = converter,
            let out = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: buffer.frameLength) else {
        return
      }
      
      var err: NSError?
      _ = converter.convert(to: out, error: &err) { _, inStatus in
        inStatus.pointee = .haveData
        return buffer
      }
      
      if let err = err {
        print("❌ [STTTranscriberManager] AVAudioConverter error: \(err)")
        return
      }
      
      sendBuffer = out
    } else {
      sendBuffer = buffer
    }
    
    // Send to analyzer
    inputContinuation?.yield(AnalyzerInput(buffer: sendBuffer))
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
    
    print("✅ [STTTranscriberManager] Transcription stopped")
  }
  
  /// Clear transcript
  func clearTranscript() {
    transcript = ""
    errorMessage = nil
  }
  
  deinit {
    stopTranscription()
  }
}
