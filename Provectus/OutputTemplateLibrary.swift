import Foundation

struct OutputTemplateLibrary {
    static let shared = OutputTemplateLibrary()

    let templates: [OutputTemplateID: OutputTemplate]

    var allTemplates: [OutputTemplate] {
        templates.values.sorted { $0.displayName < $1.displayName }
    }

    func template(for id: OutputTemplateID) -> OutputTemplate {
        templates[id] ?? OutputTemplateLibrary.makeModule2Template()
    }

    private init() {
        let module2 = OutputTemplateLibrary.makeModule2Template()
        let module27 = OutputTemplateLibrary.makeModule27Template()
        let csrSafety = OutputTemplateLibrary.makeCsrSafetyTemplate()
        templates = [module2.id: module2, module27.id: module27, csrSafety.id: csrSafety]
    }
}

private extension OutputTemplateLibrary {
    static func makeModule2Template() -> OutputTemplate {
        let sections: [OutputTemplate.Section] = [
            OutputTemplate.Section(
                id: "2",
                title: "Module 2: CTD Summaries",
                level: 1,
                templatePath: "2",
                children: [
                    OutputTemplate.Section(
                        id: "2.3",
                        title: "2.3 Quality Overall Summary",
                        level: 2,
                        templatePath: "2.3",
                        children: [
                            OutputTemplate.Section(id: "2.3.1", title: "2.3.1 Drug Substance", level: 3, templatePath: "2.3.1"),
                            OutputTemplate.Section(id: "2.3.2", title: "2.3.2 Drug Product", level: 3, templatePath: "2.3.2"),
                            OutputTemplate.Section(id: "2.3.3", title: "2.3.3 Appendices", level: 3, templatePath: "2.3.3")
                        ]
                    ),
                    OutputTemplate.Section(
                        id: "2.4",
                        title: "2.4 Nonclinical Overview",
                        level: 2,
                        templatePath: "2.4",
                        children: [
                            OutputTemplate.Section(id: "2.4.1", title: "2.4.1 Pharmacology", level: 3, templatePath: "2.4.1"),
                            OutputTemplate.Section(id: "2.4.2", title: "2.4.2 Pharmacokinetics", level: 3, templatePath: "2.4.2"),
                            OutputTemplate.Section(id: "2.4.3", title: "2.4.3 Toxicology", level: 3, templatePath: "2.4.3")
                        ]
                    ),
                    OutputTemplate.Section(
                        id: "2.5",
                        title: "2.5 Clinical Overview",
                        level: 2,
                        templatePath: "2.5",
                        children: [
                            OutputTemplate.Section(id: "2.5.1", title: "2.5.1 Product Development Rationale", level: 3, templatePath: "2.5.1"),
                            OutputTemplate.Section(id: "2.5.2", title: "2.5.2 Clinical Pharmacology", level: 3, templatePath: "2.5.2"),
                            OutputTemplate.Section(id: "2.5.3", title: "2.5.3 Summary of Efficacy", level: 3, templatePath: "2.5.3"),
                            OutputTemplate.Section(id: "2.5.4", title: "2.5.4 Summary of Safety", level: 3, templatePath: "2.5.4")
                        ]
                    ),
                    OutputTemplate.Section(
                        id: "2.6",
                        title: "2.6 Nonclinical Written and Tabulated Summaries",
                        level: 2,
                        templatePath: "2.6",
                        children: [
                            OutputTemplate.Section(id: "2.6.1", title: "2.6.1 Pharmacology Written Summary", level: 3, templatePath: "2.6.1"),
                            OutputTemplate.Section(id: "2.6.2", title: "2.6.2 Pharmacology Tabulated Summary", level: 3, templatePath: "2.6.2"),
                            OutputTemplate.Section(id: "2.6.3", title: "2.6.3 Pharmacokinetics", level: 3, templatePath: "2.6.3"),
                            OutputTemplate.Section(id: "2.6.4", title: "2.6.4 Toxicology", level: 3, templatePath: "2.6.4")
                        ]
                    ),
                    OutputTemplate.Section(
                        id: "2.7",
                        title: "2.7 Clinical Summary",
                        level: 2,
                        templatePath: "2.7",
                        children: makeClinicalSummarySections(levelOffset: 1)
                    )
                ]
            )
        ]

        return OutputTemplate(
            id: .ctdModule2,
            displayName: OutputTemplateID.ctdModule2.displayName,
            description: "Structured CTD Module 2 summary scaffold covering Quality, Nonclinical, and Clinical domains.",
            defaultFileName: "CTD_Module2_Summary.docx",
            sections: sections
        )
    }

    static func makeModule27Template() -> OutputTemplate {
        let sections = makeClinicalSummarySections(levelOffset: 0)
        return OutputTemplate(
            id: .ctdModule2ClinicalSummary,
            displayName: OutputTemplateID.ctdModule2ClinicalSummary.displayName,
            description: "Focused Module 2.7 Clinical Summary outline with sub-section placeholders.",
            defaultFileName: "CTD_Module2_7_Clinical_Summary.docx",
            sections: [
                OutputTemplate.Section(
                    id: "2.7",
                    title: "2.7 Clinical Summary",
                    level: 1,
                    templatePath: "2.7",
                    children: sections
                )
            ]
        )
    }

    static func makeCsrSafetyTemplate() -> OutputTemplate {
        let sections: [OutputTemplate.Section] = [
            OutputTemplate.Section(
                id: "1",
                title: "1 Study Identification",
                level: 1,
                templatePath: "1"
            ),
            OutputTemplate.Section(
                id: "2",
                title: "2 Synopsis",
                level: 1,
                templatePath: "2"
            ),
            OutputTemplate.Section(
                id: "3",
                title: "3 Ethics",
                level: 1,
                templatePath: "3"
            ),
            OutputTemplate.Section(
                id: "4",
                title: "4 Study Administrative Structure",
                level: 1,
                templatePath: "4"
            ),
            OutputTemplate.Section(
                id: "5",
                title: "5 Introduction",
                level: 1,
                templatePath: "5"
            ),
            OutputTemplate.Section(
                id: "6",
                title: "6 Study Objectives",
                level: 1,
                templatePath: "6"
            ),
            OutputTemplate.Section(
                id: "7",
                title: "7 Investigational Plan",
                level: 1,
                templatePath: "7",
                children: [
                    OutputTemplate.Section(id: "7.1", title: "7.1 Overall Study Design", level: 2, templatePath: "7.1"),
                    OutputTemplate.Section(id: "7.2", title: "7.2 Treatment Regimens", level: 2, templatePath: "7.2"),
                    OutputTemplate.Section(id: "7.3", title: "7.3 Safety Assessments", level: 2, templatePath: "7.3")
                ]
            ),
            OutputTemplate.Section(
                id: "8",
                title: "8 Study Population",
                level: 1,
                templatePath: "8",
                children: [
                    OutputTemplate.Section(id: "8.1", title: "8.1 Disposition", level: 2, templatePath: "8.1"),
                    OutputTemplate.Section(id: "8.2", title: "8.2 Protocol Deviations", level: 2, templatePath: "8.2"),
                    OutputTemplate.Section(id: "8.3", title: "8.3 Exposure", level: 2, templatePath: "8.3")
                ]
            ),
            OutputTemplate.Section(
                id: "9",
                title: "9 Efficacy Summary",
                level: 1,
                templatePath: "9"
            ),
            OutputTemplate.Section(
                id: "10",
                title: "10 Safety Summary",
                level: 1,
                templatePath: "10",
                children: [
                    OutputTemplate.Section(id: "10.1", title: "10.1 Analysis Sets", level: 2, templatePath: "10.1"),
                    OutputTemplate.Section(id: "10.2", title: "10.2 Adverse Events", level: 2, templatePath: "10.2", children: [
                        OutputTemplate.Section(id: "10.2.1", title: "10.2.1 Overview of Adverse Events", level: 3, templatePath: "10.2.1"),
                        OutputTemplate.Section(id: "10.2.2", title: "10.2.2 Serious Adverse Events", level: 3, templatePath: "10.2.2"),
                        OutputTemplate.Section(id: "10.2.3", title: "10.2.3 Adverse Events Leading to Discontinuation", level: 3, templatePath: "10.2.3")
                    ]),
                    OutputTemplate.Section(id: "10.3", title: "10.3 Laboratory Evaluations", level: 2, templatePath: "10.3"),
                    OutputTemplate.Section(id: "10.4", title: "10.4 Vital Signs and ECGs", level: 2, templatePath: "10.4"),
                    OutputTemplate.Section(id: "10.5", title: "10.5 Other Safety Assessments", level: 2, templatePath: "10.5")
                ]
            ),
            OutputTemplate.Section(
                id: "11",
                title: "11 Conclusions",
                level: 1,
                templatePath: "11"
            )
        ]

        return OutputTemplate(
            id: .csrSafetySummary,
            displayName: OutputTemplateID.csrSafetySummary.displayName,
            description: "CSR safety narrative scaffold aligned with ICH E3 expectations for safety sections.",
            defaultFileName: "CSR_Safety_Summary.docx",
            sections: sections
        )
    }

    static func makeClinicalSummarySections(levelOffset: Int) -> [OutputTemplate.Section] {
        let baseLevel = 1 + levelOffset
        let subLevel = baseLevel + 1
        let subSubLevel = subLevel + 1
        return [
            OutputTemplate.Section(
                id: "2.7.1",
                title: "2.7.1 Summary of Biopharmaceutics and Associated Analytical Methods",
                level: baseLevel,
                templatePath: "2.7.1"
            ),
            OutputTemplate.Section(
                id: "2.7.2",
                title: "2.7.2 Summary of Clinical Pharmacology Studies",
                level: baseLevel,
                templatePath: "2.7.2",
                children: [
                    OutputTemplate.Section(id: "2.7.2.1", title: "2.7.2.1 Pharmacokinetics", level: subLevel, templatePath: "2.7.2.1"),
                    OutputTemplate.Section(id: "2.7.2.2", title: "2.7.2.2 Pharmacodynamics", level: subLevel, templatePath: "2.7.2.2")
                ]
            ),
            OutputTemplate.Section(
                id: "2.7.3",
                title: "2.7.3 Summary of Clinical Efficacy",
                level: baseLevel,
                templatePath: "2.7.3",
                children: [
                    OutputTemplate.Section(id: "2.7.3.1", title: "2.7.3.1 Study Populations", level: subLevel, templatePath: "2.7.3.1"),
                    OutputTemplate.Section(id: "2.7.3.2", title: "2.7.3.2 Primary and Secondary Endpoints", level: subLevel, templatePath: "2.7.3.2"),
                    OutputTemplate.Section(id: "2.7.3.3", title: "2.7.3.3 Statistical Considerations", level: subLevel, templatePath: "2.7.3.3")
                ]
            ),
            OutputTemplate.Section(
                id: "2.7.4",
                title: "2.7.4 Summary of Clinical Safety",
                level: baseLevel,
                templatePath: "2.7.4",
                children: [
                    OutputTemplate.Section(id: "2.7.4.1", title: "2.7.4.1 Extent of Exposure", level: subLevel, templatePath: "2.7.4.1"),
                    OutputTemplate.Section(id: "2.7.4.2", title: "2.7.4.2 Adverse Events", level: subLevel, templatePath: "2.7.4.2", children: [
                        OutputTemplate.Section(id: "2.7.4.2.1", title: "2.7.4.2.1 Overall Adverse Events", level: subSubLevel, templatePath: "2.7.4.2.1"),
                        OutputTemplate.Section(id: "2.7.4.2.2", title: "2.7.4.2.2 Serious Adverse Events", level: subSubLevel, templatePath: "2.7.4.2.2"),
                        OutputTemplate.Section(id: "2.7.4.2.3", title: "2.7.4.2.3 Relevant Subgroup Analyses", level: subSubLevel, templatePath: "2.7.4.2.3")
                    ]),
                    OutputTemplate.Section(id: "2.7.4.3", title: "2.7.4.3 Clinical Laboratory Evaluations", level: subLevel, templatePath: "2.7.4.3"),
                    OutputTemplate.Section(id: "2.7.4.4", title: "2.7.4.4 Vital Signs", level: subLevel, templatePath: "2.7.4.4"),
                    OutputTemplate.Section(id: "2.7.4.5", title: "2.7.4.5 Conclusions", level: subLevel, templatePath: "2.7.4.5")
                ]
            ),
            OutputTemplate.Section(
                id: "2.7.5",
                title: "2.7.5 Literature References",
                level: baseLevel,
                templatePath: "2.7.5"
            ),
            OutputTemplate.Section(
                id: "2.7.6",
                title: "2.7.6 Appendices",
                level: baseLevel,
                templatePath: "2.7.6"
            ),
            OutputTemplate.Section(
                id: "2.7.7",
                title: "2.7.7 Summary Tables",
                level: baseLevel,
                templatePath: "2.7.7"
            )
        ]
    }
}