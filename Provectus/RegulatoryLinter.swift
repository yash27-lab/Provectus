import Foundation

struct RegulatoryLinter {
    func lint(result: DraftGenerationResult) -> [RegulatoryLint] {
        lint(template: result.template, sections: result.sections, documents: result.sourceDocuments)
    }

    func lint(template: OutputTemplate, sections: [DraftSection]) -> [RegulatoryLint] {
        var lints: [RegulatoryLint] = []
        lints.append(contentsOf: checkHeadingHierarchy(sections: sections))
        lints.append(contentsOf: checkMissingCitations(sections: sections))
        lints.append(contentsOf: checkNumericWithoutCitation(sections: sections))
        lints.append(contentsOf: checkUndefinedAcronyms(sections: sections))
        lints.append(contentsOf: checkBrokenCrossReferences(sections: sections))
        return lints
    }

    public func lint(template: OutputTemplate, sections: [DraftSection], documents: [SourceDocument]) -> [RegulatoryLint] {
        var lints = lint(template: template, sections: sections)
        lints.append(contentsOf: checkBadSourceCapture(documents: documents))
        return lints
    }

    // MARK: - Rules

    private func checkHeadingHierarchy(sections: [DraftSection]) -> [RegulatoryLint] {
        var lints: [RegulatoryLint] = []
        let flat = sections.flatMap { $0.flattenedSections }
        var lastLevel: Int = 0
        for section in flat {
            let level = section.level
            if lastLevel > 0 && level > lastLevel + 1 {
                let msg = "Heading level jumps from H\(lastLevel) to H\(level) at \(section.title)"
                lints.append(RegulatoryLint(severity: .warning, kind: .headingHierarchy, message: msg, hint: "Avoid skipping heading levels (e.g., H2→H4).", sectionID: section.id))
            }
            lastLevel = level
        }
        return lints
    }

    private func checkMissingCitations(sections: [DraftSection]) -> [RegulatoryLint] {
        var lints: [RegulatoryLint] = []
        for section in sections.flatMap({ $0.flattenedSections }) {
            for sentence in section.sentences where sentence.citationIDs.isEmpty {
                let msg = "Sentence has no citation: \(truncate(sentence.text))"
                lints.append(RegulatoryLint(severity: .warning, kind: .missingCitation, message: msg, hint: "Add a source citation or mark as rationale.", sectionID: section.id, sentenceID: sentence.id))
            }
        }
        return lints
    }

    private func checkNumericWithoutCitation(sections: [DraftSection]) -> [RegulatoryLint] {
        var lints: [RegulatoryLint] = []
        let numberRegex = try! NSRegularExpression(pattern: "[0-9]+(\\.[0-9]+)?", options: [])
        for section in sections.flatMap({ $0.flattenedSections }) {
            for sentence in section.sentences where sentence.citationIDs.isEmpty {
                let text = sentence.text
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if numberRegex.firstMatch(in: text, options: [], range: range) != nil {
                    let msg = "Numeric value without citation: \(truncate(text))"
                    lints.append(RegulatoryLint(severity: .warning, kind: .numericWithoutCitation, message: msg, hint: "Provide a source for reported values.", sectionID: section.id, sentenceID: sentence.id))
                }
            }
        }
        return lints
    }

    private func checkUndefinedAcronyms(sections: [DraftSection]) -> [RegulatoryLint] {
        var lints: [RegulatoryLint] = []
        var defined: Set<String> = []
        let defineRegex = try! NSRegularExpression(pattern: "\\b([A-Za-z][A-Za-z0-9\\- ]{2,}?)\\s*\\(([A-Z]{2,})\\)", options: [])
        let acronymRegex = try! NSRegularExpression(pattern: "\\b([A-Z]{2,})\\b", options: [])

        let allSentences = sections.flatMap { $0.allSentences }
        for sentence in allSentences {
            let text = sentence.text
            let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
            // Capture definitions like "Study X (SXY)"
            defineRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 3, let range = Range(match.range(at: 2), in: text) else { return }
                let acronym = String(text[range])
                defined.insert(acronym)
            }
            // Flag uppercase tokens not defined yet
            acronymRegex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match = match, let range = Range(match.range(at: 1), in: text) else { return }
                let token = String(text[range])
                guard token.count >= 2 else { return }
                if !defined.contains(token) {
                    let msg = "Undefined acronym: \(token)"
                    lints.append(RegulatoryLint(severity: .info, kind: .undefinedAcronym, message: msg, hint: "Define on first use, e.g., ‘Term (\(token))’.", sentenceID: sentence.id))
                }
            }
        }
        return lints
    }

    private func checkBrokenCrossReferences(sections: [DraftSection]) -> [RegulatoryLint] {
        var lints: [RegulatoryLint] = []
        let seeRegex = try! NSRegularExpression(pattern: "see\\s+(Table|Figure)\\s+([A-Za-z0-9\\-]+)", options: [.caseInsensitive])
        let presentRegex = try! NSRegularExpression(pattern: "\\b(Table|Figure)\\s+([A-Za-z0-9\\-]+)\\b", options: [])

        let allTexts = sections.flatMap { $0.allSentences }.map { $0.text }
        var present: Set<String> = []
        for text in allTexts {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            presentRegex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match = match, match.numberOfRanges >= 3,
                      let kindRange = Range(match.range(at: 1), in: text),
                      let idRange = Range(match.range(at: 2), in: text) else { return }
                let key = "\(text[kindRange]) \(text[idRange])".lowercased()
                present.insert(key)
            }
        }

        for section in sections.flatMap({ $0.flattenedSections }) {
            for sentence in section.sentences {
                let text = sentence.text
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                seeRegex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    guard let match = match, match.numberOfRanges >= 3,
                          let kindRange = Range(match.range(at: 1), in: text),
                          let idRange = Range(match.range(at: 2), in: text) else { return }
                    let key = "\(text[kindRange]) \(text[idRange])".lowercased()
                    if !present.contains(key) {
                        let msg = "Cross-reference not found: \(key)"
                        lints.append(RegulatoryLint(severity: .warning, kind: .brokenCrossReference, message: msg, hint: "Ensure the referenced Table/Figure exists.", sectionID: section.id, sentenceID: sentence.id))
                    }
                }
            }
        }
        return lints
    }

    private func checkBadSourceCapture(documents: [SourceDocument]) -> [RegulatoryLint] {
        var lints: [RegulatoryLint] = []
        for doc in documents where doc.invalidExcerptCount > 0 {
            let msg = "Bad source capture (HTML/403) in \(doc.displayName): \(doc.invalidExcerptCount) quarantined chunk(s)."
            lints.append(RegulatoryLint(severity: .error, kind: .badSourceCapture, message: msg, hint: "Verify the source file content and re-import a valid PDF/DOCX (avoid web error pages or HTML)."))
        }
        return lints
    }

    // MARK: - Helpers

    private func truncate(_ text: String, limit: Int = 120) -> String {
        if text.count <= limit { return text }
        let idx = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<idx]) + "…"
    }
}
