import Foundation

/// A minimal Word (.docx) exporter for demo purposes.
/// Produces headings, paragraphs, and an optional traceability table.
struct DocxExporter {
    /// Exports the given DraftDocument to a .docx file data with the provided configuration.
    /// - Parameters:
    ///   - document: The DraftDocument to export.
    ///   - config: Configuration options for export.
    /// - Returns: A DocxExportArtifact containing the file name and data.
    func export(document: DraftDocument, config: DocxExportConfiguration) -> DocxExportArtifact {
        let fileName = document.template.defaultFileName
        let parts = buildParts(document: document, config: config)
        let data = ZipArchive.buildDocx(parts: parts)
        return DocxExportArtifact(fileName: fileName, data: data)
    }

    private func buildParts(document: DraftDocument, config: DocxExportConfiguration) -> [ZipArchive.Part] {
        let mainDocumentXML = buildMainDocumentXML(document: document, config: config)
        var parts: [ZipArchive.Part] = []
        parts.append(ZipArchive.Part(path: "[Content_Types].xml", data: Data(contentTypesXML.utf8)))
        parts.append(ZipArchive.Part(path: "_rels/.rels", data: Data(packageRelsXML.utf8)))
        parts.append(ZipArchive.Part(path: "word/document.xml", data: Data(mainDocumentXML.utf8)))
        parts.append(ZipArchive.Part(path: "word/_rels/document.xml.rels", data: Data(documentRelsXML.utf8)))
        parts.append(ZipArchive.Part(path: "docProps/app.xml", data: Data(appXML.utf8)))
        parts.append(ZipArchive.Part(path: "docProps/core.xml", data: Data(coreXML(creator: "Provectus", title: document.template.displayName).utf8)))
        return parts
    }

    private func buildMainDocumentXML(document: DraftDocument, config: DocxExportConfiguration) -> String {
        var xml: [String] = []
        xml.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>")
        xml.append("<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">")
        xml.append("<w:body>")

        // Optional TOC placeholder (Word can generate on open)
        if config.includeTableOfContents {
            xml.append("<w:p><w:r><w:t>Table of Contents (update in Word)</w:t></w:r></w:p>")
        }

        // Sections and sentences
        for section in document.sections.flatMap({ $0.flattenedSections }) {
            xml.append(headingParagraph(title: section.title, level: section.level))
            for sentence in section.sentences {
                xml.append(paragraph(text: sentence.text))
            }
        }

        if config.includeTraceabilityTable {
            xml.append(traceabilityTable(document: document))
        }

        xml.append("</w:body>")
        xml.append("</w:document>")
        return xml.joined()
    }

    private func headingParagraph(title: String, level: Int) -> String {
        let lvl = max(1, min(level, 9))
        return "<w:p><w:pPr><w:pStyle w:val=\"Heading\(lvl)\"/></w:pPr><w:r><w:t>\(escape(title))</w:t></w:r></w:p>"
    }

    private func paragraph(text: String) -> String {
        return "<w:p><w:r><w:t xml:space=\"preserve\">\(escape(text))</w:t></w:r></w:p>"
    }

    private func traceabilityTable(document: DraftDocument) -> String {
        var rows: [String] = []
        rows.append(tableRow(cells: ["Sentence", "Source", "Page", "Excerpt Hash"]))
        for entry in document.traceability.entries {
            let sentence = entry.sentenceText
            if let link = entry.links.first {
                let src = link.documentName
                let page = String(link.pageNumber)
                let hash = link.excerptID
                rows.append(tableRow(cells: [sentence, src, page, hash]))
            } else {
                rows.append(tableRow(cells: [sentence, "—", "—", "—"]))
            }
        }
        let tbl = "<w:tbl>\(rows.joined())</w:tbl>"
        return tbl
    }

    private func tableRow(cells: [String]) -> String {
        let cellsXML = cells.map { cell in
            "<w:tc><w:p><w:r><w:t xml:space=\"preserve\">\(escape(cell))</w:t></w:r></w:p></w:tc>"
        }.joined()
        return "<w:tr>\(cellsXML)</w:tr>"
    }

    private func escape(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "&", with: "&amp;")
        s = s.replacingOccurrences(of: "<", with: "&lt;")
        s = s.replacingOccurrences(of: ">", with: "&gt;")
        s = s.replacingOccurrences(of: "\"", with: "&quot;")
        return s
    }
}

// MARK: - Static XML parts

private let contentTypesXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"""

private let packageRelsXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="/word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="/docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="/docProps/app.xml"/>
</Relationships>
"""

private func coreXML(creator: String, title: String) -> String {
    return """
<?xml version="1.0" encoding="UTF-8"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>\(title)</dc:title>
  <dc:creator>\(creator)</dc:creator>
  <cp:lastModifiedBy>\(creator)</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">\(ISO8601DateFormatter().string(from: Date()))</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">\(ISO8601DateFormatter().string(from: Date()))</dcterms:modified>
</cp:coreProperties>
"""
}

private let appXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Provectus</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <Company/>
  <LinksUpToDate>false</LinksUpToDate>
  <SharedDoc>false</SharedDoc>
  <HyperlinksChanged>false</HyperlinksChanged>
  <AppVersion>16.0000</AppVersion>
</Properties>
"""

private let documentRelsXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>
"""

// MARK: - Minimal Zip (Store only)

private enum ZipArchive {
    struct Part { let path: String; let data: Data }

    /// Builds a .docx zip archive from the given parts using store (no compression).
    /// - Parameter parts: Array of file parts with paths and data.
    /// - Returns: The zipped archive data.
    static func buildDocx(parts: [Part]) -> Data {
        var centralDirectory: [Data] = []
        var fileData = Data()
        var offset: UInt32 = 0

        for part in parts {
            let local = localHeader(name: part.path, data: part.data)
            fileData.append(local)
            fileData.append(part.data)
            let central = centralHeader(name: part.path, data: part.data, offset: offset)
            centralDirectory.append(central)
            offset = UInt32(fileData.count)
        }

        let cdOffset = UInt32(fileData.count)
        var cd = Data()
        for entry in centralDirectory { cd.append(entry) }
        fileData.append(cd)
        let end = endOfCentralDirectory(count: UInt16(parts.count), size: UInt32(cd.count), offset: cdOffset)
        fileData.append(end)
        return fileData
    }

    private static func localHeader(name: String, data: Data) -> Data {
        var d = Data()
        d.append(signature(0x04034b50))
        d.append(uint16(20)) // version needed
        d.append(uint16(0))  // flags
        d.append(uint16(0))  // compression (0 = store)
        d.append(uint16(0))  // mod time
        d.append(uint16(0))  // mod date
        d.append(uint32(crc32(data)))
        d.append(uint32(UInt32(data.count)))
        d.append(uint32(UInt32(data.count)))
        let nameData = Data(name.utf8)
        d.append(uint16(UInt16(nameData.count)))
        d.append(uint16(0)) // extra len
        d.append(nameData)
        return d
    }

    private static func centralHeader(name: String, data: Data, offset: UInt32) -> Data {
        var d = Data()
        d.append(signature(0x02014b50))
        d.append(uint16(20)) // version made by
        d.append(uint16(20)) // version needed
        d.append(uint16(0))  // flags
        d.append(uint16(0))  // compression
        d.append(uint16(0))  // mod time
        d.append(uint16(0))  // mod date
        d.append(uint32(crc32(data)))
        d.append(uint32(UInt32(data.count)))
        d.append(uint32(UInt32(data.count)))
        let nameData = Data(name.utf8)
        d.append(uint16(UInt16(nameData.count)))
        d.append(uint16(0)) // extra
        d.append(uint16(0)) // comment
        d.append(uint16(0)) // disk number
        d.append(uint16(0)) // internal attrs
        d.append(uint32(0)) // external attrs
        d.append(uint32(offset))
        d.append(nameData)
        return d
    }

    private static func endOfCentralDirectory(count: UInt16, size: UInt32, offset: UInt32) -> Data {
        var d = Data()
        d.append(signature(0x06054b50))
        d.append(uint16(0)) // disk number
        d.append(uint16(0)) // cd start disk
        d.append(uint16(count))
        d.append(uint16(count))
        d.append(uint32(size))
        d.append(uint32(offset))
        d.append(uint16(0)) // comment len
        return d
    }

    private static func signature(_ value: UInt32) -> Data { var v = value.littleEndian; return Data(bytes: &v, count: 4) }
    private static func uint16(_ value: UInt16) -> Data { var v = value.littleEndian; return Data(bytes: &v, count: 2) }
    private static func uint32(_ value: UInt32) -> Data { var v = value.littleEndian; return Data(bytes: &v, count: 4) }

    // Simple CRC32 (IEEE 802.3)
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data { crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)] }
        return crc ^ 0xFFFFFFFF
    }

    private static let table: [UInt32] = {
        (0..<(256)).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
            return c
        }
    }()
}

