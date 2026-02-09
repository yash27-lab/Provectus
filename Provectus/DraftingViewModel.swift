import Foundation
import SwiftUI
import Combine

@MainActor
final class DraftingViewModel: ObservableObject {
    struct SourceRecord: Identifiable {
        let id: UUID
        let imported: ImportedSource
        var document: SourceDocument?
        var error: DraftingError?

        var statusDescription: String {
            if let document {
                return "\(document.excerpts.count) excerpts"
            }
            if let error {
                return error.errorDescription ?? "Error"
            }
            return "Pending"
        }

        init(imported: ImportedSource, document: SourceDocument? = nil, error: DraftingError? = nil) {
            self.id = imported.id
            self.imported = imported
            self.document = document
            self.error = error
        }
    }

    enum DraftingError: LocalizedError, Identifiable {
        case unsupportedType(fileName: String)
        case fileReadFailed(fileName: String)
        case parsingFailed(fileName: String, underlying: Error)
        case remoteURLNotAllowed(fileName: String)

        var id: String { localizedDescription }

        var errorDescription: String? {
            switch self {
            case .unsupportedType(let fileName):
                return "Unsupported file type: \(fileName)"
            case .fileReadFailed(let fileName):
                return "Could not read file: \(fileName)"
            case .parsingFailed(let fileName, let error):
                let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                return "Failed to parse \(fileName): \(detail)"
            case .remoteURLNotAllowed(let fileName):
                return "External URLs are not allowed: \(fileName)"
            }
        }
    }

    @Published private(set) var sourceRecords: [SourceRecord] = []
    @Published var selectedTemplateID: OutputTemplateID = .ctdModule2ClinicalSummary
    @Published private(set) var generationResult: DraftGenerationResult?
    @Published private(set) var isProcessing = false
    @Published var statusMessage: String?
    @Published var alertMessage: String?

    private let templateLibrary = OutputTemplateLibrary.shared
    private let parsingPipeline = ParsingPipeline()
    private let draftGenerator = DraftGenerator()
    private let linter = RegulatoryLinter()
    private let exporter = DocxExporter()

    var selectedTemplate: OutputTemplate {
        templateLibrary.template(for: selectedTemplateID)
    }

    var availableDocuments: [SourceDocument] {
        let docs = sourceRecords.compactMap { $0.document }
        var seen: Set<String> = []
        var unique: [SourceDocument] = []
        for doc in docs {
            // Use first excerpt hash as a quick proxy; fallback to id
            let key = doc.excerpts.first?.hashToken ?? doc.id.uuidString
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(doc)
            }
        }
        return unique
    }

    var canGenerate: Bool {
        !availableDocuments.isEmpty && !isProcessing
    }

    func importFiles(at urls: [URL]) {
        guard !urls.isEmpty else { return }
        isProcessing = true
        statusMessage = "Collecting sources…"
        alertMessage = nil
        resetGeneration()

        Task.detached { [weak self] in
            guard let self else { return }
            let pipeline = await MainActor.run { self.parsingPipeline }
            var newRecords: [SourceRecord] = []

            for url in urls {
                let didStartAccess = url.startAccessingSecurityScopedResource()
                defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

                let fileName = url.lastPathComponent
                
                guard url.isFileURL else {
                    let imported = ImportedSource(fileName: fileName, data: Data(), contentType: .unknown, originalURL: url)
                    newRecords.append(SourceRecord(imported: imported, document: nil, error: .remoteURLNotAllowed(fileName: fileName)))
                    continue
                }

                do {
                    let data = try Data(contentsOf: url)
                    let type = self.determineType(for: url)
                    guard type != .unknown else {
                        let error = DraftingError.unsupportedType(fileName: fileName)
                        let imported = ImportedSource(fileName: fileName, data: data, contentType: type, originalURL: url)
                        newRecords.append(SourceRecord(imported: imported, document: nil, error: error))
                        continue
                    }

                    let imported = ImportedSource(fileName: fileName, data: data, contentType: type, originalURL: url)
                    let parsed = try pipeline.parse(source: imported)
                    newRecords.append(SourceRecord(imported: imported, document: parsed, error: nil))
                } catch {
                    let nsError = error as NSError
                    let draftError: DraftingError
                    if nsError.code == NSFileReadNoSuchFileError || nsError.code == NSFileReadUnknownError {
                        draftError = .fileReadFailed(fileName: fileName)
                    } else if let parsingError = error as? ParsingPipelineError {
                        draftError = .parsingFailed(fileName: fileName, underlying: parsingError)
                    } else {
                        draftError = .parsingFailed(fileName: fileName, underlying: error)
                    }
                    let imported = ImportedSource(fileName: fileName, data: Data(), contentType: .unknown, originalURL: url)
                    newRecords.append(SourceRecord(imported: imported, document: nil, error: draftError))
                }
            }

            await MainActor.run {
                self.sourceRecords.append(contentsOf: newRecords)
                self.statusMessage = nil
                self.isProcessing = false
                let failed = newRecords.filter { $0.document == nil }
                if !failed.isEmpty {
                    let example = failed.first?.error?.errorDescription ?? "Unknown error"
                    if failed.count == newRecords.count {
                        self.alertMessage = "No files could be processed. Example: \(example)"
                    } else {
                        self.alertMessage = "\(failed.count) of \(newRecords.count) files could not be processed. Example: \(example)"
                    }
                }
            }
        }
    }

    func removeSources(at offsets: IndexSet) {
        guard !isProcessing else { return }
        sourceRecords.remove(atOffsets: offsets)
        resetGeneration()
    }

    func clearAll() {
        guard !isProcessing else { return }
        sourceRecords.removeAll()
        resetGeneration()
    }

    func generateDraft() {
        guard canGenerate else { return }
        isProcessing = true
        statusMessage = "Generating draft…"
        alertMessage = nil

        let documents = availableDocuments
        let template = selectedTemplate

        Task.detached { [weak self] in
            guard let self else { return }
            let generator = await MainActor.run { self.draftGenerator }
            let result = generator.generate(template: template, sourceDocuments: documents)
            await MainActor.run {
                self.generationResult = result
                self.isProcessing = false
                self.statusMessage = nil
            }
        }
    }

    func resetGeneration() {
        generationResult = nil
    }

    func exportDocx() -> DocxExportArtifact? {
        return exportDocx(config: DocxExportConfiguration())
    }

    func exportDocx(config: DocxExportConfiguration) -> DocxExportArtifact? {
        guard let result = generationResult else { return nil }
        let draft = DraftGenerator().makeDraftDocument(from: result)
        return exporter.export(document: draft, config: config)
    }

    nonisolated private func determineType(for url: URL) -> SourceDocumentType {
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty {
            let type = SourceDocumentType(fileExtension: ext)
            if type != .unknown {
                return type
            }
        }
        return .unknown
    }
}

