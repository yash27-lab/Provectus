// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProvectusCoreChecks",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ProvectusCore", path: "Provectus", exclude: ["Assets.xcassets", "ContentView.swift", "CSVFileDocument.swift", "DocxExporter.swift", "DocxFileDocument.swift", "DraftGenerator.swift", "DraftingViewModel.swift", "ParsingPipeline.swift", "ProvectusApp.swift", "ProvectusDocument.swift", "RegulatoryLinter.swift"], sources: ["DomainModels.swift", "OutputTemplateLibrary.swift"]),
        .testTarget(name: "CoreChecks", dependencies: ["ProvectusCore"], path: "CoreChecks")
    ]
)
