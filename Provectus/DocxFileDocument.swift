import SwiftUI
import UniformTypeIdentifiers

struct DocxFileDocument: FileDocument, Identifiable {
    static var readableContentTypes: [UTType] { [.data] }
    static var writableContentTypes: [UTType] {
        if let docx = UTType(filenameExtension: "docx") { return [docx] }
        return [.data]
    }

    let id = UUID()
    var fileName: String
    var data: Data

    init(fileName: String, data: Data) {
        self.fileName = fileName
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.fileName = "Export.docx"
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
}
