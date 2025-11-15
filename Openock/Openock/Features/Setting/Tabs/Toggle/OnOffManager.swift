//
//  OnOffManager.swift
//  Openock
//
//  Created by YONGWON SEO on 11/12/25.
//

import Foundation
import Combine

/// 설정의 기능 토글을 구독해 AudioPipeline에 적용/정리하는 매니저
final class OnOffManager {
  private let pipeline: AudioPipeline
  private let settings: SettingsManager
  private var bag = Set<AnyCancellable>()

  init(pipeline: AudioPipeline, settings: SettingsManager) {
    self.pipeline = pipeline
    self.settings = settings
    bind()
    // 앱 시작 시 저장된 상태를 즉시 반영
    applyAll(
      sizeFX: settings.toggleSizeFX,
      yam: settings.toggleYamReactions,
      whistle: settings.toggleWhistle
    )
  }

  private func bind() {
    settings.$toggleSizeFX
      .removeDuplicates()
      .sink { [weak self] v in self?.pipeline.applySizeFXEnabled(v) }
      .store(in: &bag)

    settings.$toggleYamReactions
      .removeDuplicates()
      .sink { [weak self] v in self?.pipeline.applyYamReactionsEnabled(v) }
      .store(in: &bag)

    settings.$toggleWhistle
      .removeDuplicates()
      .sink { [weak self] v in self?.pipeline.applyWhistleEnabled(v) }
      .store(in: &bag)
  }

  private func applyAll(sizeFX: Bool, yam: Bool, whistle: Bool) {
    pipeline.applySizeFXEnabled(sizeFX)
    pipeline.applyYamReactionsEnabled(yam)
    pipeline.applyWhistleEnabled(whistle)
  }
}
