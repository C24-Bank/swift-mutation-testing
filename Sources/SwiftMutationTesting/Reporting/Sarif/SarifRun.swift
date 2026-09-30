struct SarifRun: Sendable, Encodable {
    let tool: SarifTool
    let originalUriBaseIds: [String: SarifArtifactLocation]
    let columnKind = "utf16CodeUnits"
    let results: [SarifResult]
}
