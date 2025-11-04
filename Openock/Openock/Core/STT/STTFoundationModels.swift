//
//  STTFoundationModels.swift
//  Openock
//
//  Created by JiJooMaeng on 11/4/25.
//

/*
 STT Foundation Models Manager

 Abstract:
 Uses Apple's Foundation Models to improve STT transcription results
 by applying contextual corrections, grammar fixes, and proper spacing.
 */

import Foundation
import FoundationModels

class STTFoundationModels {

    // MARK: - Properties

    /// Singleton instance
    static let shared = STTFoundationModels()

    /// Foundation Models session
    private var session: LanguageModelSession?

    /// Configuration for text improvement
    struct Configuration {
        /// Maximum length of text to process at once
        let maxTextLength: Int

        /// Whether to use streaming
        let useStreaming: Bool

        /// Temperature for generation (0.0 = deterministic, 1.0 = creative)
        let temperature: Double

        /// Top P sampling
        let topP: Double

        static let `default` = Configuration(
            maxTextLength: 500,
            useStreaming: false,
            temperature: 0.1,  // 매우 낮게 설정 - 일관된 교정
            topP: 0.8  // 상위 80% 토큰만 사용
        )
    }

    private let configuration: Configuration

    // MARK: - Initialization

    private init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Initialize Foundation Models session
    func initialize() async throws {
        print("🔄 [STTFoundationModels] Initializing Foundation Models...")

        // Check if model is available
        switch SystemLanguageModel.default.availability {
        case .available:
            print("✅ [STTFoundationModels] Model is available")
        case .unavailable(let reason):
            print("❌ [STTFoundationModels] Model unavailable: \(reason)")
            throw STTFoundationModelsError.modelNotAvailable
        }

        // Create session with system instructions
        self.session = LanguageModelSession {
            """
            당신은 한국어 음성인식(STT) 오류를 적극적으로 수정하는 전문가입니다.

            핵심 원칙:
            1. **맥락이 전부입니다** - 이전 대화를 꼭 읽고 주제를 파악하세요
            2. **말이 안 되는 단어는 과감히 수정** - "이표먹으" 같은 무의미한 단어는 맥락에 맞게 교정
            3. 고유명사(선수명, 지명, 인명) 최우선 수정
            4. 스포츠/기술 전문 용어 수정
            5. 말투와 어투는 절대 변경 금지

            STT 오류 패턴:
            - 발음이 비슷한 다른 단어로 잘못 인식됨
            - 띄어쓰기 오류
            - 숫자 + 단어 조합 오류 ("2피홈런" → "이피홈런" 같은)

            예시:
            맥락: "야구 경기 투수가 공을 던졌어"
            STT: "이표먹으를 맞았어"
            수정: "2 피홈런을 맞았어"

            맥락: "농구 경기에서"
            STT: "쓰리포인터 던졌다"
            수정: "3점슛을 던졌다"

            맥락: "미국 대통령이"
            STT: "배악관에서 발표했다"
            수정: "백악관에서 발표했다"

            맥락: "축구 선수"
            STT: "손홍민이 골을"
            수정: "손흥민이 골을"

            **중요**:
            - 맥락을 최우선으로 고려
            - 말이 안 되는 단어는 유사 발음의 올바른 단어로 대체
            - 수정된 텍스트만 출력 (설명 없이)
            """
        }

        // Prewarm for better performance
        session?.prewarm()

        print("✅ [STTFoundationModels] Foundation Models initialized")
    }

    /// Improve transcribed text with alternative candidates
    /// - Parameters:
    ///   - candidates: Multiple transcription candidates (first is primary)
    ///   - previousContext: Previous finalized text for better context (optional)
    /// - Returns: Improved text (best candidate selected and corrected)
    func improveTextWithAlternatives(candidates: [String], previousContext: String? = nil) async throws -> String {
        guard !candidates.isEmpty else { return "" }

        // 후보가 하나뿐이면 기존 방식 사용
        if candidates.count == 1 {
            return try await improveText(candidates[0], previousContext: previousContext)
        }

        // Initialize session if needed
        if session == nil {
            try await initialize()
        }

        guard let session = session else {
            throw STTFoundationModelsError.sessionNotInitialized
        }

        print("🔄 [STTFoundationModels] Evaluating \(candidates.count) candidates")

        // Build prompt with alternatives
        let prompt = buildPromptWithAlternatives(candidates: candidates, context: previousContext)

        do {
            let options = GenerationOptions(temperature: configuration.temperature)
            let output = try await session.respond(to: prompt, options: options)
            let improvedText = output.content.trimmingCharacters(in: .whitespacesAndNewlines)

            print("✅ [STTFoundationModels] Selected and improved: '\(improvedText)'")
            return improvedText

        } catch let error as LanguageModelSession.GenerationError {
            print("❌ [STTFoundationModels] Generation error: \(error.localizedDescription)")
            return candidates[0]
        } catch {
            print("❌ [STTFoundationModels] Error: \(error)")
            return candidates[0]
        }
    }

    /// Improve transcribed text with contextual corrections
    /// - Parameters:
    ///   - text: Original STT transcription text
    ///   - previousContext: Previous finalized text for better context (optional)
    /// - Returns: Improved text
    func improveText(_ text: String, previousContext: String? = nil) async throws -> String {
        guard !text.isEmpty else { return text }

        // Initialize session if needed
        if session == nil {
            try await initialize()
        }

        guard let session = session else {
            throw STTFoundationModelsError.sessionNotInitialized
        }

        print("🔄 [STTFoundationModels] Improving text: '\(text)'")
        if let previousContext = previousContext {
            print("📖 [STTFoundationModels] Context: '\(previousContext)'")
        }

        // Build prompt
        let prompt = buildPrompt(for: text, context: previousContext)
        print("📝 [STTFoundationModels] Prompt:\n\(prompt)\n")

        do {
            // Request text improvement with low temperature for consistency
            let options = GenerationOptions(temperature: configuration.temperature)
            let output = try await session.respond(to: prompt, options: options)
            let improvedText = output.content.trimmingCharacters(in: .whitespacesAndNewlines)

            print("✅ [STTFoundationModels] Improved: '\(text)' → '\(improvedText)'")
            return improvedText

        } catch let error as LanguageModelSession.GenerationError {
            print("❌ [STTFoundationModels] Generation error: \(error.localizedDescription)")
            // Return original text if improvement fails
            return text
        } catch {
            print("❌ [STTFoundationModels] Error improving text: \(error)")
            return text
        }
    }

    /// Improve text with streaming support (for real-time display)
    /// - Parameters:
    ///   - text: Original STT transcription text
    ///   - previousContext: Previous finalized text for better context (optional)
    /// - Returns: AsyncStream of improved text chunks
    func improveTextStreaming(_ text: String, previousContext: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Initialize session if needed
                    if session == nil {
                        try await initialize()
                    }

                    guard let session = session else {
                        throw STTFoundationModelsError.sessionNotInitialized
                    }

                    let prompt = buildPrompt(for: text, context: previousContext)

                    // Stream results
                    let stream = session.streamResponse(to: prompt)
                    for try await output in stream {
                        continuation.yield(output.content)
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Build prompt for text improvement with alternative candidates
    private func buildPromptWithAlternatives(candidates: [String], context: String?) -> String {
        var prompt = ""

        if let context = context, !context.isEmpty {
            prompt += "[이전 대화]\n\(context)\n\n"
        }

        prompt += "[음성인식 후보들]\n"
        for (index, candidate) in candidates.enumerated() {
            prompt += "\(index + 1). \(candidate)\n"
        }

        prompt += "\n[작업]\n"
        prompt += "위 후보 중 맥락에 가장 맞는 것을 선택하고, 필요시 최소한으로 수정하세요.\n"
        prompt += "여러 후보를 조합해도 됩니다."

        return prompt
    }

    /// Build prompt for text improvement
    private func buildPrompt(for text: String, context: String?) -> String {
        var prompt = ""

        if let context = context, !context.isEmpty {
            prompt += "=== 이전 대화 맥락 (주제 파악 필수) ===\n\(context)\n\n"
        } else {
            prompt += "=== 이전 대화 맥락 ===\n(없음 - 첫 문장)\n\n"
        }

        prompt += "=== 음성인식 결과 (오류 있음) ===\n\(text)\n\n"
        prompt += "=== 작업 ===\n"
        prompt += "1. 위 맥락에서 주제가 무엇인지 파악\n"
        prompt += "2. 음성인식 결과에서 맥락에 맞지 않는 단어 찾기\n"
        prompt += "3. 유사 발음의 올바른 단어로 교정\n"
        prompt += "4. 수정된 텍스트만 출력 (설명 없이)\n\n"
        prompt += "수정된 텍스트:"

        return prompt
    }

    /// Clean up resources
    func cleanup() {
        print("🛑 [STTFoundationModels] Cleaning up...")
        session = nil
    }

    deinit {
        cleanup()
    }
}

// MARK: - Error Handling

@available(macOS 15.1, *)
enum STTFoundationModelsError: LocalizedError {
    case sessionNotInitialized
    case modelNotAvailable
    case textTooLong

    var errorDescription: String? {
        switch self {
        case .sessionNotInitialized:
            return "Foundation Models session is not initialized"
        case .modelNotAvailable:
            return "Foundation Models is not available on this device"
        case .textTooLong:
            return "Text is too long to process"
        }
    }
}

// MARK: - Convenience Extensions

@available(macOS 15.1, *)
extension STTFoundationModels {

    /// Batch improve multiple text segments
    func improveBatch(_ texts: [String], previousContext: String? = nil) async throws -> [String] {
        var results: [String] = []
        var context = previousContext

        for text in texts {
            let improved = try await improveText(text, previousContext: context)
            results.append(improved)

            // Update context for next iteration
            if let ctx = context {
                context = ctx + " " + improved
            } else {
                context = improved
            }
        }

        return results
    }

    /// Check if Foundation Models is available
    static func isAvailable() -> Bool {
        if #available(macOS 15.1, *) {
            return true
        }
        return false
    }
}
