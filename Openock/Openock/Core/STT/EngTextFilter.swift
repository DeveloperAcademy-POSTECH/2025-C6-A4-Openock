//
//  EngTextFilter.swift
//  Openock
//
//  Created by JiJooMaeng on 11/19/25.
//

/*
 English Text Filter

 Abstract:
 Provides text filtering utilities for STT transcription results.
 Can filter out English characters while preserving Korean text, numbers, and punctuation.
 */

import Foundation

class EngTextFilter {

    // MARK: - Properties

    /// Singleton instance
    static let shared = EngTextFilter()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Filter out English characters and keep only Korean text
    /// - Parameter text: Original text to filter
    /// - Returns: Filtered text with English characters removed
    func filterKoreanOnly(_ text: String) -> String {
        let filtered = text.filter { char in
            let scalar = char.unicodeScalars.first
            guard let scalarValue = scalar?.value else { return true }

            // Keep Korean characters (Hangul syllables, Jamo)
            if (0xAC00...0xD7A3).contains(scalarValue) { return true }  // Hangul syllables
            if (0x1100...0x11FF).contains(scalarValue) { return true }  // Hangul Jamo
            if (0x3130...0x318F).contains(scalarValue) { return true }  // Hangul Compatibility Jamo
            if (0xA960...0xA97F).contains(scalarValue) { return true }  // Hangul Jamo Extended-A
            if (0xD7B0...0xD7FF).contains(scalarValue) { return true }  // Hangul Jamo Extended-B

            // Keep numbers, spaces, and common punctuation
            if char.isNumber { return true }
            if char.isWhitespace { return true }
            if ".,!?;:-()[]{}\"'".contains(char) { return true }

            // Filter out English alphabet (A-Z, a-z)
            if (0x0041...0x005A).contains(scalarValue) { return false }  // A-Z
            if (0x0061...0x007A).contains(scalarValue) { return false }  // a-z

            // Keep everything else (other symbols, etc.)
            return true
        }

        return String(filtered).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if text contains Korean characters
    /// - Parameter text: Text to check
    /// - Returns: True if text contains at least one Korean character
    func containsKorean(_ text: String) -> Bool {
        return text.contains(where: { char in
            let scalar = char.unicodeScalars.first
            guard let scalarValue = scalar?.value else { return false }
            return (0xAC00...0xD7A3).contains(scalarValue)
        })
    }

    /// Check if text contains English characters
    /// - Parameter text: Text to check
    /// - Returns: True if text contains at least one English character
    func containsEnglish(_ text: String) -> Bool {
        return text.contains(where: { char in
            let scalar = char.unicodeScalars.first
            guard let scalarValue = scalar?.value else { return false }
            return (0x0041...0x005A).contains(scalarValue) || (0x0061...0x007A).contains(scalarValue)
        })
    }

    /// Get the percentage of Korean characters in text
    /// - Parameter text: Text to analyze
    /// - Returns: Percentage of Korean characters (0.0 to 1.0)
    func koreanPercentage(_ text: String) -> Double {
        guard !text.isEmpty else { return 0.0 }

        let koreanCount = text.filter { char in
            let scalar = char.unicodeScalars.first
            guard let scalarValue = scalar?.value else { return false }
            return (0xAC00...0xD7A3).contains(scalarValue)
        }.count

        return Double(koreanCount) / Double(text.count)
    }
}
