//
//  ContextAnalyzer.swift
//  Openock
//
//  Created by ellllly on 11/4/25.
//
import Foundation
import Combine
import SwiftUI // openWindow/dismissWindow 사용을 위해 필요

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ContextAnalyzer: ObservableObject {
  @Published var latestCategory: String = "해당 없음"
  @Published var lastInput: String = ""
  
  enum Category: String, CaseIterable {
    case 득점 = "득점"
    case 반칙 = "반칙"
    case 옐로카드 = "옐로 카드"
    case 레드카드 = "레드 카드"
    case 전반전종료 = "전반전 종료"
    case 후반전시작 = "후반전 시작"
    case 해당없음 = "해당 없음"
  }
  
  private let transcriptSubject = PassthroughSubject<String, Never>()
  private var cancellables = Set<AnyCancellable>()
  
  private let basePrompt: String = """
  너는 축구 경기의 실시간 중계 자막을 분석하는 AI야.
  주어진 문장이 어떤 의미를 담고 있는지 아래의 의미 목록 중 하나로 분류해줘.
  문맥상 의미를 고려해서 판단해야 하며, 반드시 하나의 결과만 선택해야 해.
  해당되지 않으면 '해당 없음'으로 답해.
  
  <의미 목록>
  1. 득점 — 골이 들어갔거나, 슛이 득점으로 연결된 상황
  2. 반칙 — 반칙, 오프사이드, 핸드볼, 파울 등 규칙 위반 상황
  3. 옐로 카드 — 심판이 옐로카드를 주는 상황, 경고 상황
  4. 레드 카드 — 심판이 레드카드를 주는 상황, 퇴장 상황
  5. 전반전 종료 — 전반전이 끝나는 상황
  6. 후반전 시작 — 후반전이 시작되는 상황
  
  출력은 다음 중 하나의 텍스트만 반환해:
  득점, 반칙, 옐로 카드, 레드 카드, 전반전 종료, 후반전 시작, 해당 없음
  """
  
  func updateTranscript(_ transcript: String) {
    self.transcriptSubject.send(transcript)
  }
  
  // Combine 파이프라인에서 async 함수를 Publisher로 감싸 switchToLatest를 사용할 수 있게 수정
  func subscribeToAnalysis(overlay: OverlayManager, openWindow: OpenWindowAction, dismissWindow: DismissWindowAction) {
    // 이미 구독이 설정되어 있다면 중복 방지
    guard cancellables.isEmpty else { return }
    
    transcriptSubject
      .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    // 각 transcript를 Publisher<String, Never>로 변환
      .map { [weak self] transcript -> AnyPublisher<String, Never> in
        guard let self = self else {
          return Just(Category.해당없음.rawValue).eraseToAnyPublisher()
        }
        return Deferred {
          Future<String, Never> { promise in
            Task { [weak self] in
              guard let self = self else {
                promise(.success(Category.해당없음.rawValue))
                return
              }
              let result = await self.analyze(transcript: transcript)
              promise(.success(result))
            }
          }
        }
        .eraseToAnyPublisher()
      }
      .switchToLatest() // 최신 요청의 결과만 방출
      .sink { [weak self] label in
        guard let _ = self else { return }
        if label != Category.해당없음.rawValue {
          overlay.show(label)
          openWindow(id: "eventOverlay")
        } else {
          overlay.hide()
          dismissWindow(id: "eventOverlay")
        }
      }
      .store(in: &cancellables)
  }
  
  func analyze(transcript: String, context: String? = nil) async -> String {
    let input = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    lastInput = input
    guard !input.isEmpty else {
      latestCategory = Category.해당없음.rawValue
      print("🧠 [ContextAnalyzer] Empty input → \(latestCategory)")
      return latestCategory
    }
    
    if let fmResult = await classifyWithFoundationModel(transcript: input, context: context) {
      latestCategory = fmResult
      print("🧠 [ContextAnalyzer] FM result → \(latestCategory) | input: \(input)")
      return latestCategory
    }
    
    let local = classifyHeuristically(input: input)
    latestCategory = local
    print("🧠 [ContextAnalyzer] Heuristic result → \(latestCategory) | input: \(input)")
    return latestCategory
  }
  
  // 간단한 키워드 기반 휴리스틱 분류기
  private func classifyHeuristically(input: String) -> String {
    let lower = input.lowercased()
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // 득점 관련
    let goalKeywords = ["득점", "골", "스코어", "equalizer", "동점골", "결승골", "해트트릭", "헤트트릭"]
    if goalKeywords.contains(where: { lower.contains($0) || trimmed.contains($0) }) {
      return Category.득점.rawValue
    }
    
    // 레드 카드 (먼저 체크: 더 강한 이벤트)
    let redKeywords = ["레드카드", "레드 카드", "퇴장", "퇴장입니다", "퇴장을"]
    if redKeywords.contains(where: { lower.contains($0) || trimmed.contains($0) }) {
      return Category.레드카드.rawValue
    }
    
    // 옐로 카드
    let yellowKeywords = ["옐로카드", "옐로 카드", "경고", "카드가 나옵니다", "카드를 꺼냅니다"]
    if yellowKeywords.contains(where: { lower.contains($0) || trimmed.contains($0) }) {
      return Category.옐로카드.rawValue
    }
    
    // 반칙
    let foulKeywords = ["반칙", "파울", "오프사이드", "핸드볼", "프리킥", "페널티킥", "pk", "파울입니다"]
    if foulKeywords.contains(where: { lower.contains($0) || trimmed.contains($0) }) {
      return Category.반칙.rawValue
    }
    
    // 전반전 종료
    let htEndKeywords = ["전반전 종료", "전반 종료", "하프타임", "half-time", "half time"]
    if htEndKeywords.contains(where: { lower.contains($0) || trimmed.contains($0) }) {
      return Category.전반전종료.rawValue
    }
    
    // 후반전 시작
    let secondHalfStartKeywords = ["후반전 시작", "후반 시작", "kick-off", "킥오프", "재개합니다", "경기 재개"]
    if secondHalfStartKeywords.contains(where: { lower.contains($0) || trimmed.contains($0) }) {
      return Category.후반전시작.rawValue
    }
    
    return Category.해당없음.rawValue
  }
  
  private func logFMError(_ error: Error) {
    print("❌ [ContextAnalyzer] Foundation Model error: \(error.localizedDescription)")
  }
  
  private func classifyWithFoundationModel(transcript: String, context: String?) async -> String? {
#if canImport(FoundationModels)
    return nil
#else
    return nil
#endif
  }
}

