import Foundation

struct DraftGenerationResult {
    let template: OutputTemplate
    let sections: [DraftSection]
    let citationsByID: [String: Citation]
    let sourceDocuments: [SourceDocument]
    let traceability: TraceabilityReport
    let lints: [RegulatoryLint]
}

struct DraftGenerator {
    func generate(template: OutputTemplate, sourceDocuments: [SourceDocument]) -> DraftGenerationResult {
        var pool = ExcerptPool(documents: sourceDocuments)
        var citationOrdinal = 1
        var citationMap: [String: Citation] = [:]
        var traceEntries: [TraceabilityEntry] = []
        let sections = template.sections.map { section in
            buildSection(
                from: section,
                pool: &pool,
                citationOrdinal: &citationOrdinal,
                citationMap: &citationMap,
                traceEntries: &traceEntries
            )
        }
        let traceability = TraceabilityReport(entries: traceEntries)
        let lints = RegulatoryLinter().lint(template: template, sections: sections, documents: sourceDocuments)
        return DraftGenerationResult(
            template: template,
            sections: sections,
            citationsByID: citationMap,
            sourceDocuments: sourceDocuments,
            traceability: traceability,
            lints: lints
        )
    }

    private func buildSection(
        from templateSection: OutputTemplate.Section,
        pool: inout ExcerptPool,
        citationOrdinal: inout Int,
        citationMap: inout [String: Citation],
        traceEntries: inout [TraceabilityEntry]
    ) -> DraftSection {
        let selectedItems = pool.selectBest(for: templateSection, limit: 1)
        var sentences: [DraftSentence] = []

        for item in selectedItems {
            let ordinal = citationOrdinal
            citationOrdinal += 1
            let citation = Citation(
                excerptID: item.excerpt.id,
                documentID: item.document.id,
                pageIndex: item.excerpt.pageIndex,
                ordinal: ordinal
            )
            citationMap[citation.id] = citation
            let snippet = item.excerpt.preview
            let descriptive = "Key details for \(templateSection.title) come from \(item.document.displayName) (p. \(item.excerpt.pageNumber)): \(snippet)"
            let sentenceText = descriptive + " " + citation.displayLabel
            let sentence = DraftSentence(text: sentenceText, citationIDs: [citation.id], order: sentences.count)
            sentences.append(sentence)
            let link = TraceabilityLink(
                citationID: citation.id,
                documentName: item.document.displayName,
                pageNumber: item.excerpt.pageNumber,
                excerptPreview: snippet,
                excerptID: item.excerpt.id
            )
            let entry = TraceabilityEntry(sentenceID: sentence.id, sentenceText: sentence.text, links: [link])
            traceEntries.append(entry)
        }

        if sentences.isEmpty {
            let placeholder = DraftSentence(text: "Placeholder: Author to provide content for \(templateSection.title).", citationIDs: [], order: 0)
            sentences.append(placeholder)
            let entry = TraceabilityEntry(sentenceID: placeholder.id, sentenceText: placeholder.text, links: [])
            traceEntries.append(entry)
        }

        var childSections: [DraftSection] = []
        for child in templateSection.children {
            let builtChild = buildSection(
                from: child,
                pool: &pool,
                citationOrdinal: &citationOrdinal,
                citationMap: &citationMap,
                traceEntries: &traceEntries
            )
            childSections.append(builtChild)
        }

        return DraftSection(
            templatePath: templateSection.templatePath,
            title: templateSection.title,
            level: templateSection.level,
            sentences: sentences,
            children: childSections
        )
    }
}

private struct ExcerptPool {
    struct Item {
        let excerpt: SourceExcerpt
        let document: SourceDocument
    }

    private(set) var items: [Item]
    private var usedExcerptIDs: Set<String> = []

    init(documents: [SourceDocument]) {
        items = documents.flatMap { document in
            document.excerpts.map { Item(excerpt: $0, document: document) }
        }
    }

    mutating func selectBest(for section: OutputTemplate.Section, limit: Int) -> [Item] {
        guard !items.isEmpty else { return [] }
        let available = items.filter { !usedExcerptIDs.contains($0.excerpt.id) }
        if available.isEmpty {
            usedExcerptIDs.removeAll()
            return selectBest(for: section, limit: limit)
        }
        let scored = available.map { item -> (Item, Int) in
            (item, KeywordExtractor.score(item: item, for: section))
        }.sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                if lhs.0.document.id == rhs.0.document.id {
                    return lhs.0.excerpt.pageIndex < rhs.0.excerpt.pageIndex
                }
                return lhs.0.document.displayName < rhs.0.document.displayName
            }
            return lhs.1 > rhs.1
        }
        var chosen: [Item] = []
        for (item, score) in scored {
            if !KeywordExtractor.hasMeaningfulKeywords(for: section) || score > 0 || chosen.isEmpty {
                chosen.append(item)
                usedExcerptIDs.insert(item.excerpt.id)
            }
            if chosen.count == limit { break }
        }
        if chosen.isEmpty, let fallback = scored.first?.0 {
            usedExcerptIDs.insert(fallback.excerpt.id)
            return [fallback]
        }
        return chosen
    }
}

private enum KeywordExtractor {
    static func keywords(from section: OutputTemplate.Section) -> [String] {
        var tokens: Set<String> = []
        let base = section.title + " " + section.templatePath
        let cleaned = base.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        for token in cleaned {
            if token.count < 3 { continue }
            if stopWords.contains(token) { continue }
            tokens.insert(token)
        }
        additionalKeywords(for: section.templatePath).forEach { tokens.insert($0) }
        return Array(tokens)
    }

    static func score(item: ExcerptPool.Item, for section: OutputTemplate.Section) -> Int {
        let text = item.excerpt.text.lowercased()
        let documentName = item.document.displayName.lowercased()
        let keywords = keywords(from: section)
        guard !keywords.isEmpty else { return 1 }
        var score = 0
        for keyword in keywords {
            if text.contains(keyword) { score += 4 }
            if documentName.contains(keyword) { score += 2 }
        }
        score += affinityBonus(for: section.templatePath, in: text)
        return score
    }

    static func hasMeaningfulKeywords(for section: OutputTemplate.Section) -> Bool {
        !keywords(from: section).isEmpty
    }

    private static func affinityBonus(for templatePath: String, in text: String) -> Int {
        var bonus = 0
        if templatePath.hasPrefix("2.7.4") {
            if text.contains("adverse") { bonus += 3 }
            if text.contains("safety") { bonus += 2 }
        }
        if templatePath.hasPrefix("2.7.3") {
            if text.contains("efficacy") { bonus += 3 }
            if text.contains("endpoint") { bonus += 2 }
        }
        if templatePath.hasPrefix("10.2") {
            if text.contains("adverse") { bonus += 3 }
        }
        return bonus
    }

    private static func additionalKeywords(for templatePath: String) -> [String] {
        switch templatePath {
        case "2.7", "2.7.4":
            return ["safety", "adverse", "event"]
        case "2.7.3":
            return ["efficacy", "endpoint"]
        case "2.7.2":
            return ["pharmacokinetic", "pharmacodynamic"]
        case "2.3":
            return ["quality", "manufacturing", "substance", "product"]
        case "2.5":
            return ["clinical", "overview"]
        case "10.2":
            return ["adverse", "event", "safety"]
        default:
            return []
        }
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "summary", "section", "module", "clinical", "nonclinical", "study", "analysis"
    ]
}
extension DraftGenerator {
    func makeDraftDocument(from result: DraftGenerationResult) -> DraftDocument {
        return DraftDocument(
            template: result.template,
            sections: result.sections,
            citationsByID: result.citationsByID,
            sourceDocuments: result.sourceDocuments,
            generatedAt: Date(),
            traceability: result.traceability,
            lints: result.lints
        )
    }
}

