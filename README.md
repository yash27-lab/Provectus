# Provectus — Word Draft + Traceability Inspector

Word-first regulatory drafting prototype that generates CTD/CSR DOCX drafts with sentence-level citations, source excerpt preview, traceability coverage, and exportable audit reports.

## What it does
- Generates CTD/CSR draft structure and content as **DOCX**
- Adds inline citations like **[CIT-001]** for each paragraph
- Click a citation to view the **source excerpt** (document + page + snippet)
- Produces a **traceability report** with coverage (e.g., 21/21 paragraphs cited)
- Exports an **audit CSV** for QC and review workflows
- Runs locally on macOS (documents stay on-device)

## Demo
Add screenshots or a short 45–60s video walkthrough here.

Suggested flow:
1. Add Source Bundle (PDF/DOCX)
2. Choose output type (CTD 2.7 / CSR)
3. Generate Draft (DOCX)
4. Click [CIT-###] → Source Excerpt
5. Export CSV

## Why this matters
Regulatory teams draft in Word and reviewers need fast verification. This prototype focuses on provenance-first drafting so every claim is traceable back to its source.

## Run locally
1. Open `Provectus.xcodeproj` in Xcode
2. Select macOS target
3. Build & Run

## Notes
- Prototype built for demonstrating word-first drafting + traceability workflows.
- Not intended for real regulatory submissions without validation.
