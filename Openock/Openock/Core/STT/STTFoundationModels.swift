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
            당신은 한국어 음성인식(STT)의 **명백한 오류만** 수정하는 전문가입니다.

            **절대 금지 사항** (어떤 경우에도 수정 불가):
            1. 감탄사 제거/변경 ("아", "어", "음", "으" 등) - 절대 건드리지 마세요
            2. 시간 표현 ("지금", "이제", "나중에", "아까" 등) - 절대 건드리지 마세요
            3. 문장 구조나 어순 변경 - 원본 그대로 유지
            4. 부사/형용사 제거 ("정말", "아주", "매우" 등) - 원본 그대로
            5. 말투 변경 ("~네요", "~어요", "~습니다" 등) - 원본 그대로

            **수정 가능한 경우** (오직 이 경우만):
            1. 완전히 무의미한 음절 조합 ("이표먹으", "배악관", "사슥" 같은 nonsense 단어)
            2. 명백한 고유명사 오타 ("손홍민" → "손흥민", "다더스" → "다저스")
            3. 숫자 음성 오류 ("이피홈런" → "2피홈런")

            **예시 - 수정하면 안 되는 것**:
            STT: "아 지금쯤 손님이 사슥 들어와야 되네요"
            수정: "아 지금쯤 손님이 슬슬 들어와야 되네요"
            (❌ "아 지금쯤"을 절대 제거하면 안 됨!)

            STT: "음 이제 시작해볼까요"
            수정: "음 이제 시작해볼까요"
            (감탄사와 시간 표현 그대로 유지)

            **예시 - 수정해야 하는 것**:
            STT: "다더스가 홈런을 쳤어요"
            수정: "다저스가 홈런을 쳤어요"
            (명백한 고유명사 오타만 수정)

            STT: "손홍민 선수가 골을 넣었어"
            수정: "손흥민 선수가 골을 넣었어"
            (명백한 고유명사 오타만 수정)

            **핵심**:
            - 의미 있는 단어면 절대 수정하지 마세요
            - 불확실하면 100% 원본 그대로 반환
            - 단어 하나도 제거/추가하지 마세요
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
            prompt += "[이전 대화 (참고용)]\n\(context)\n\n"
        }

        prompt += "[음성인식 후보들]\n"
        for (index, candidate) in candidates.enumerated() {
            prompt += "\(index + 1). \(candidate)\n"
        }

        prompt += "\n[작업]\n"
        prompt += "1. 가장 자연스러운 후보를 선택 (불확실하면 1번)\n"
        prompt += "2. 명백한 오류만 최소한으로 수정\n"
        prompt += "3. 수정된 텍스트만 출력"

        return prompt
    }

    /// Build prompt for text improvement
    private func buildPrompt(for text: String, context: String?) -> String {
        var prompt = ""

        if let context = context, !context.isEmpty {
            prompt += "=== 이전 대화 (참고용) ===\n\(context)\n\n"
        } else {
            prompt += "=== 이전 대화 ===\n(없음)\n\n"
        }

        prompt += "=== 음성인식 결과 ===\n\(text)\n\n"
        prompt += "=== 작업 ===\n"
        prompt += "1. 명백한 STT 오류만 찾기 (무의미한 음절, 명백한 고유명사 오타)\n"
        prompt += "2. 불확실하면 수정하지 말 것\n"
        prompt += "3. 수정된 텍스트만 출력 (설명 없이, 수정 없으면 원본 그대로)\n\n"
        prompt += "텍스트:"

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
