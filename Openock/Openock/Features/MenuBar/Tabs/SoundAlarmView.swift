//
//  SoundAlarmView.swift
//  Openock
//
//  Created by JiJooMaeng on 10/28/25.
//

import SwiftUI

struct SoundAlarmView: View {
  // MARK: - State
  @State private var newWord: String = ""
  @State private var words: [WordItem] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 상단 입력 영역
      VStack(alignment: .leading, spacing: 8) {
        Text("단어추가")
          .font(.system(size: 11))
          .fontWeight(.semibold)

        HStack(spacing: 8) {
          TextField("단어를 입력하세요", text: $newWord)
            .textFieldStyle(.plain)
            .padding(6)
            .background(Color.white)
            .cornerRadius(5)
            .overlay(
              RoundedRectangle(cornerRadius: 5)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .onSubmit(addWord)

          Button(action: addWord) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 22, weight: .semibold))
              .foregroundStyle(.blue)
          }
          .buttonStyle(.plain)
          .help("단어 추가")
        }
      }
      
      Text("단어 리스트")
        .font(.system(size: 11))
        .fontWeight(.semibold)
      
      Form {
        Section {
          ForEach($words) { $item in
            HStack(spacing: 12) {
              Button {
                item.isOn.toggle()
              } label: {
                Image(systemName: item.isOn ? "checkmark.circle.fill" : "circle")
                  .font(.system(size: 13, weight: .semibold))
                  .symbolRenderingMode(.hierarchical)
              }
              .buttonStyle(.plain)

              Text(item.text)
                .font(.system(size: 13, weight: .regular))

              Spacer()
            }
            .padding(.vertical, -4)
          }
          .onDelete { indexSet in
            words.remove(atOffsets: indexSet)
          }
        }
      }
      .formStyle(.grouped)
      .padding(.horizontal, -24)
      .padding(.vertical, -24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  // MARK: - Actions
  private func addWord() {
    let text = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    if !words.map({ $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).contains(text.lowercased()) {
      words.insert(WordItem(text: text, isOn: true), at: 0)
    }
    newWord = ""
  }
}

// MARK: - Model
private struct WordItem: Identifiable, Equatable {
  let id = UUID()
  var text: String
  var isOn: Bool
}

#Preview {
  SoundAlarmView()
}
