import SwiftUI
import UniformTypeIdentifiers

struct CSVFileDocument: FileDocument, Identifiable {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] {
        if let csv = UTType(filenameExtension: "csv") { return [csv] }
        return [.plainText]
    }

    let id = UUID()
    var fileName: String
    var data: Data

    init(fileName: String, data: Data) {
        self.fileName = fileName
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.fileName = "Export.csv"
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
}
