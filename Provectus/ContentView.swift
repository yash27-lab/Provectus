import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ContentView: View {
    @ObservedObject var viewModel: DraftingViewModel
    @State private var isImporterPresented = false
    @State private var selectedLink: TraceabilityLink? = nil
    @State private var isExporterPresented = false
    @State private var exportDoc: DocxFileDocument? = nil
    @State private var lastExportedURL: URL? = nil
    @State private var isCSVExporterPresented = false
    @State private var csvDoc: CSVFileDocument? = nil

    private var supportedTypes: [UTType] {
        var types: [UTType] = [.pdf]
        if let docx = UTType(filenameExtension: "docx") { types.append(docx) }
        if let doc = UTType(filenameExtension: "doc") { types.append(doc) }
        return types
    }
    
    private var csvContentType: UTType {
        UTType(filenameExtension: "csv") ?? .plainText
    }

    private var docxContentType: UTType {
        UTType(filenameExtension: "docx") ?? .data
    }
    
    private var docxDefaultFilename: String {
        exportDoc?.fileName ?? viewModel.selectedTemplate.defaultFileName
    }
    
    private var docxDocument: DocxFileDocument {
        exportDoc ?? DocxFileDocument(fileName: viewModel.selectedTemplate.defaultFileName, data: Data())
    }
    
    private var csvDocument: CSVFileDocument {
        csvDoc ?? CSVFileDocument(fileName: "Traceability.csv", data: Data())
    }
    
    private var csvDefaultFilename: String {
        csvDoc?.fileName ?? "Traceability.csv"
    }
    
    var body: some View {
        navigationContent
    }
    
    private var navigationContent: some View {
        NavigationStack {
            mainScrollView
                .navigationTitle("Word Draft + Traceability Inspector")
                .toolbar { toolbarContent }
                .fileImporter(
                    isPresented: $isImporterPresented,
                    allowedContentTypes: supportedTypes,
                    allowsMultipleSelection: true,
                    onCompletion: handleImport
                )
                .alert("Notice", isPresented: alertBinding) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.alertMessage ?? "An unknown error occurred.")
                }
                .sheet(item: $selectedLink) { link in
                    TraceLinkDetailView(link: link)
                }
                .fileExporter(
                    isPresented: $isExporterPresented,
                    document: docxDocument,
                    contentType: docxContentType,
                    defaultFilename: docxDefaultFilename,
                    onCompletion: handleDocxExportResult
                )
                .fileExporter(
                    isPresented: $isCSVExporterPresented,
                    document: csvDocument,
                    contentType: csvContentType,
                    defaultFilename: csvDefaultFilename,
                    onCompletion: handleCSVExportResult
                )
        }
    }
    
    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                sourceSection
                templateSection
                if let result = viewModel.generationResult {
                    draftSection(result)
                }
            }
            .padding()
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if !viewModel.sourceRecords.isEmpty {
                Button(role: .destructive) {
                    viewModel.clearAll()
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
            }
            Button {
                isImporterPresented = true
            } label: {
                Label("Add Sources", systemImage: "plus.circle.fill")
            }
            .disabled(viewModel.isProcessing)
        }
    }
    
    private var alertBinding: Binding<Bool> {
        Binding<Bool>(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )
    }
    private func handleDocxExportResult(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            viewModel.alertMessage = "Export failed: \(error.localizedDescription)"
        }
        exportDoc = nil
    }
    
    private func handleCSVExportResult(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            viewModel.alertMessage = "Export failed: \(error.localizedDescription)"
        }
        csvDoc = nil
    }

    private var sourceSection: some View {
        Section {
            if viewModel.sourceRecords.isEmpty {
                ContentUnavailableView("No Source Documents", systemImage: "doc.questionmark", description: Text("Add PDF and DOCX files to get started."))
            } else {
                ForEach(Array(viewModel.sourceRecords.indexed()), id: \.1.id) { index, record in
                    sourceRecordRow(index: index, record: record)
                }
            }
        } header: {
            Text("Source Bundle").font(.headline)
        }
    }
    
    private func sourceRecordRow(index: Int, record: DraftingViewModel.SourceRecord) -> some View {
        HStack {
            Image(systemName: record.document != nil ? "checkmark.circle.fill" : record.error != nil ? "exclamationmark.triangle.fill" : "doc.badge.plus")
                .foregroundColor(record.document != nil ? .green : record.error != nil ? .orange : .gray)
            VStack(alignment: .leading) {
                Text(record.imported.fileName).fontWeight(.semibold)
                Text(record.statusDescription).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                viewModel.removeSources(at: IndexSet(integer: index))
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
        }
        .padding(.bottom, 8)
    }

    private var templateSection: some View {
        Section {
            outputTypePicker
            processingStatusView
            actionButtons
        } header: {
            Text("Output Configuration").font(.headline)
        }
    }
    
    private var outputTypePicker: some View {
        Picker("Output Type", selection: $viewModel.selectedTemplateID) {
            ForEach(OutputTemplateID.allCases, id: \.self) { templateId in
                Text(templateId.displayName).tag(templateId)
            }
        }
        .pickerStyle(.menu)
        .disabled(viewModel.isProcessing)
    }
    
    private var processingStatusView: some View {
        Group {
            if viewModel.isProcessing, let status = viewModel.statusMessage {
                HStack {
                    ProgressView()
                    Text(status).font(.callout).foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 4) {
            generateDraftButton
            #if os(macOS)
            macOSActionButtons
            #endif
            exportButton
        }
        .padding(.top, 8)
    }
    
    private var generateDraftButton: some View {
        Button {
            viewModel.generateDraft()
        } label: {
            Label("Generate Draft (DOCX)", systemImage: "doc.text.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.canGenerate)
    }
    
    #if os(macOS)
    private var macOSActionButtons: some View {
        HStack {
            Button {
                if let url = saveDocxToTemporary() {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open DOCX", systemImage: "doc.richtext")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.generationResult == nil)

            Button {
                if let url = saveDocxToTemporary() {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.generationResult == nil)
        }
    }
    #endif
    
    private var exportButton: some View {
        Button {
            if let artifact = viewModel.exportDocx() {
                exportDoc = DocxFileDocument(fileName: artifact.fileName, data: artifact.data)
                isExporterPresented = true
            } else {
                viewModel.alertMessage = "Generate a draft before exporting."
            }
        } label: {
            Label("Export DOCX", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(viewModel.generationResult == nil)
    }

    private func draftSection(_ result: DraftGenerationResult) -> some View {
        Section {
            let entryDict = Dictionary(uniqueKeysWithValues: result.traceability.entries.map { ($0.id, $0) })
            let totalEntries = result.traceability.entries.count
            let citedEntries = result.traceability.entries.filter { !$0.links.isEmpty }.count

            SectionOutlineView(
                sections: result.sections,
                citations: result.citationsByID,
                entryIndex: entryDict,
                onSelectLink: { selectedLink = $0 }
            )

            traceabilityReportView(totalEntries: totalEntries, citedEntries: citedEntries, result: result)

            if !result.lints.isEmpty {
                LintsView(lints: result.lints)
            }

        } header: {
            Text("Generated Draft").font(.headline)
        }
    }
    
    private func traceabilityReportView(totalEntries: Int, citedEntries: Int, result: DraftGenerationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Traceability Report").font(.subheadline).bold()
            HStack {
                Text("Coverage")
                Spacer()
                Text(String(format: "%.0f%%", result.traceability.coveragePercentage))
                    .monospacedDigit()
            }
            .font(.callout)
            Text("\(citedEntries)/\(totalEntries) paragraphs cited")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                let data = makeTraceabilityCSV(result: result)
                csvDoc = CSVFileDocument(fileName: "Traceability.csv", data: data)
                isCSVExporterPresented = true
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.down")
            }
            .font(.callout)
            .padding(.top, 4)
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            viewModel.importFiles(at: urls)
        case .failure(let error):
            viewModel.alertMessage = error.localizedDescription
        }
    }
    
    private func saveDocxToTemporary() -> URL? {
        guard let artifact = viewModel.exportDocx() else {
            viewModel.alertMessage = "Generate a draft before opening."
            return nil
        }
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(artifact.fileName)
        do {
            try artifact.data.write(to: tmpURL, options: .atomic)
            lastExportedURL = tmpURL
            return tmpURL
        } catch {
            viewModel.alertMessage = "Failed to write DOCX: \(error.localizedDescription)"
            return nil
        }
    }

    private func makeTraceabilityCSV(result: DraftGenerationResult) -> Data {
        var rows: [String] = []
        func esc(_ s: String) -> String {
            let t = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(t)\""
        }
        rows.append(["Sentence", "Source", "Page", "Excerpt Hash"].map(esc).joined(separator: ","))
        for entry in result.traceability.entries {
            if let link = entry.links.first {
                let sentence = entry.sentenceText
                let src = link.documentName
                let page = String(link.pageNumber)
                let hash = link.excerptID
                rows.append([sentence, src, page, hash].map(esc).joined(separator: ","))
            } else {
                rows.append([entry.sentenceText, "", "", ""].map(esc).joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }
}

// MARK: - Supporting Views

private struct SectionOutlineView: View {
    let sections: [DraftSection]
    let citations: [String: Citation]
    let entryIndex: [UUID: TraceabilityEntry]
    let onSelectLink: (TraceabilityLink) -> Void

    var body: some View {
        ForEach(sections) { section in
            VStack(alignment: .leading, spacing: 12) {
                Text(section.title)
                    .font(fontForLevel(section.level))
                    .padding(.leading, CGFloat(max(0, section.level - 1)) * 16)

                ForEach(section.sentences) { sentence in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sentence.text)
                        if !sentence.citationIDs.isEmpty {
                            HStack {
                                ForEach(sentence.citationIDs, id: \.self) { citationID in
                                    if let entry = entryIndex[sentence.id], let link = entry.links.first(where: { $0.citationID == citationID }) {
                                        Button {
                                            onSelectLink(link)
                                        } label: {
                                            Text(citations[citationID]?.displayLabel ?? "[?]").font(.caption).bold()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.leading, CGFloat(max(0, section.level)) * 16)
                }

                if !section.children.isEmpty {
                    SectionOutlineView(sections: section.children, citations: citations, entryIndex: entryIndex, onSelectLink: onSelectLink)
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }
}

private struct TraceLinkDetailView: View {
    let link: TraceabilityLink
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(link.documentName).font(.title).bold()
                    Text("Page: \(link.pageNumber)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(link.excerptPreview)
                        .font(.body)
                }
                .padding()
            }
            .navigationTitle("Source Excerpt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LintsView: View {
    let lints: [RegulatoryLint]
    @State private var expandedKinds: Set<RegulatoryLintKind> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Regulatory Lints").font(.subheadline).bold()
                Spacer()
                Text("\(lints.count)").font(.caption).foregroundColor(.secondary)
            }

            let groups = Dictionary(grouping: lints, by: { $0.kind })
            let sortedKinds = groups.keys.sorted {
                let lc = groups[$0]?.count ?? 0
                let rc = groups[$1]?.count ?? 0
                if lc != rc { return lc > rc }
                return $0.displayName < $1.displayName
            }

            ForEach(Array(sortedKinds), id: \.self) { kind in
                if let items = groups[kind] {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(kind.displayName) (\(items.count))")
                                .font(.callout)
                                .bold()
                            Spacer()
                        }

                        let isExpanded = expandedKinds.contains(kind)
                        let shown = isExpanded ? items : Array(items.prefix(3))

                        ForEach(shown) { lint in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(lint.severity.color).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lint.message).font(.callout)
                                    if let hint = lint.hint {
                                        Text(hint).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                        if items.count > 3 {
                            Button {
                                if isExpanded {
                                    expandedKinds.remove(kind)
                                } else {
                                    expandedKinds.insert(kind)
                                }
                            } label: {
                                Text(isExpanded ? "View less" : "View all (\(items.count))")
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Extensions

private extension RegulatoryLintSeverity {
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

private extension RegulatoryLintKind {
    var displayName: String {
        switch self {
        case .headingHierarchy: return "Heading hierarchy issues"
        case .missingCitation: return "Missing citations"
        case .numericWithoutCitation: return "Numeric values without citation"
        case .undefinedAcronym: return "Undefined acronyms"
        case .brokenCrossReference: return "Broken cross-references"
        case .badSourceCapture: return "Bad source capture (HTML/403)"
        }
    }
}

private extension Collection {
    func indexed() -> [(Int, Element)] {
        Array(self.enumerated())
    }
}

private extension Color {
    static var secondaryBackground: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: DraftingViewModel())
    }
}
#endif