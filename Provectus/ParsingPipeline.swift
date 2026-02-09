import Foundation
import NaturalLanguage
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(Vision)
import Vision
#endif

enum ParsingPipelineError: LocalizedError {
    case unsupportedType(String)
    case unreadableDocument

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let message):
            return message
        case .unreadableDocument:
            return "Unable to extract readable text from the provided source."
        }
    }
}

struct ParsingPipeline {
    var minimumChunkLength: Int = 280
    var maximumChunkLength: Int = 1200
    var enableOCRFallback: Bool = true

    func parse(source: ImportedSource) throws -> SourceDocument {
        switch source.contentType {
        case .pdf:
            return try parsePDF(source: source)
        case .docx, .doc:
            return try parseWord(source: source)
        case .unknown:
            throw ParsingPipelineError.unsupportedType("Unsupported file type for \(source.fileName)")
        }
    }

    private func parsePDF(source: ImportedSource) throws -> SourceDocument {
        #if canImport(PDFKit)
        guard let pdf = PDFDocument(data: source.data) else {
            throw ParsingPipelineError.unreadableDocument
        }
        let documentID = UUID()
        var excerpts: [SourceExcerpt] = []
        var invalidCount = 0

        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }
            // Prefer attributedString when available; fall back to plain string
            let pageText: String? = {
                if let attr = page.attributedString?.string, !attr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return attr
                }
                if let plain = page.string, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return plain
                }
                return nil
            }()
            guard let text = pageText else { continue }
            let sanitized = sanitize(pageText: text)
            let result = makeExcerptsWithInvalidCount(from: sanitized, documentID: documentID, startingPageIndex: pageIndex)
            excerpts.append(contentsOf: result.excerpts)
            invalidCount += result.invalidCount
        }

        // Fallback: some PDFs (e.g., concatenated text layers) may yield nil per-page strings
        if excerpts.isEmpty, let full = pdf.string, !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sanitized = sanitize(pageText: full)
            let result = makeExcerptsWithInvalidCount(from: sanitized, documentID: documentID, startingPageIndex: 0)
            excerpts.append(contentsOf: result.excerpts)
            invalidCount += result.invalidCount
        }

        #if canImport(Vision)
        if excerpts.isEmpty && enableOCRFallback {
            var ocrText = ""
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            for pageIndex in 0..<pdf.pageCount {
                guard let page = pdf.page(at: pageIndex) else { continue }
                let pageBounds = page.bounds(for: .mediaBox)
                #if os(iOS)
                let thumb = page.thumbnail(of: pageBounds.size, for: .mediaBox)
                guard let cgImage = thumb.cgImage else { continue }
                #elseif os(macOS)
                let thumb = page.thumbnail(of: pageBounds.size, for: .mediaBox)
                guard let cgImage = thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
                #else
                continue
                #endif
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
                let observations = request.results ?? []
                let pageText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                ocrText += pageText + "\n"
            }
            let sanitized = sanitize(pageText: ocrText)
            let result = makeExcerptsWithInvalidCount(from: sanitized, documentID: documentID, startingPageIndex: 0)
            excerpts.append(contentsOf: result.excerpts)
            invalidCount += result.invalidCount
        }
        #endif

        if excerpts.isEmpty && invalidCount == 0 {
            throw ParsingPipelineError.unreadableDocument
        }
        return SourceDocument(id: documentID, displayName: source.fileName, type: .pdf, excerpts: excerpts, invalidExcerptCount: invalidCount)
        #else
        throw ParsingPipelineError.unsupportedType("PDF parsing is unavailable on this platform")
        #endif
    }

    private func parseWord(source: ImportedSource) throws -> SourceDocument {
        let documentID = UUID()
        let fullText = try extractWordText(from: source.data)
        let sanitized = sanitize(pageText: fullText)
        let result = makeExcerptsWithInvalidCount(from: sanitized, documentID: documentID, startingPageIndex: 0)
        if result.excerpts.isEmpty && result.invalidCount == 0 {
            throw ParsingPipelineError.unreadableDocument
        }
        return SourceDocument(id: documentID, displayName: source.fileName, type: source.contentType, excerpts: result.excerpts, invalidExcerptCount: result.invalidCount)
    }

    private func extractWordText(from data: Data) throws -> String {
        let attributedAttempts: [[NSAttributedString.DocumentReadingOptionKey: Any]] = [
            [
                .documentType: NSAttributedString.DocumentType.officeOpenXML,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            [
                .documentType: NSAttributedString.DocumentType.rtf,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            [
                .documentType: NSAttributedString.DocumentType.plain,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
        ]

        for options in attributedAttempts {
            if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                let stripped = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !stripped.isEmpty {
                    return attributed.string
                }
            }
        }

        let stringEncodings: [String.Encoding] = [.utf8, .utf16, .unicode]
        for encoding in stringEncodings {
            if let string = String(data: data, encoding: encoding) {
                let stripped = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !stripped.isEmpty {
                    return string
                }
            }
        }

        throw ParsingPipelineError.unreadableDocument
    }

    private func makeExcerpts(from text: String, documentID: UUID, startingPageIndex: Int) -> [SourceExcerpt] {
        chunk(text: text, startingPageIndex: startingPageIndex).map { chunk in
            SourceExcerpt(documentID: documentID, pageIndex: chunk.pageIndex, text: chunk.text)
        }
    }

    private func makeExcerptsWithInvalidCount(from text: String, documentID: UUID, startingPageIndex: Int) -> (excerpts: [SourceExcerpt], invalidCount: Int) {
        let chunks = chunk(text: text, startingPageIndex: startingPageIndex)
        var excerpts: [SourceExcerpt] = []
        var invalid = 0

        for chunk in chunks {
            if isLikelyHTMLOrError(chunk.text) {
                invalid += 1
                continue
            }
            excerpts.append(SourceExcerpt(documentID: documentID, pageIndex: chunk.pageIndex, text: chunk.text))
        }

        return (excerpts, invalid)
    }

    private func chunk(text: String, startingPageIndex: Int) -> [(text: String, pageIndex: Int)] {
        var chunks: [(String, Int)] = []
        var current = ""
        var currentLength = 0
        var pageSlot = startingPageIndex
        let sentences = text.splitIntoSentences()
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let sentenceLength = trimmed.count
            if currentLength + sentenceLength > maximumChunkLength, !current.isEmpty {
                chunks.append((current, pageSlot))
                current = ""
                currentLength = 0
                pageSlot += 1
            }
            current.append(current.isEmpty ? trimmed : " " + trimmed)
            currentLength += sentenceLength
            if currentLength >= minimumChunkLength {
                chunks.append((current, pageSlot))
                current = ""
                currentLength = 0
                pageSlot += 1
            }
        }
        if !current.isEmpty {
            chunks.append((current, pageSlot))
        }
        return chunks
    }

    private func sanitize(pageText: String) -> String {
        let collapsed = pageText.replacingOccurrences(of: "\r", with: " ")
        let withoutTabs = collapsed.replacingOccurrences(of: "\t", with: " ")
        return withoutTabs.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func isLikelyHTMLOrError(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = ["<html", "</body", "<head", "<script", "<meta", "403 forbidden"]
        for keyword in keywords {
            if lower.contains(keyword) {
                return true
            }
        }
        let countLessThan = text.filter { $0 == "<" }.count
        let countGreaterThan = text.filter { $0 == ">" }.count
        if countLessThan + countGreaterThan >= 10 {
            return true
        }
        return false
    }
}

private extension String {
    func splitIntoSentences() -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = self
        tokenizer.enumerateTokens(in: startIndex..<endIndex) { range, _ in
            sentences.append(String(self[range]))
            return true
        }
        if sentences.isEmpty {
            return components(separatedBy: CharacterSet(charactersIn: "\n."))
        }
        return sentences
    }
}
