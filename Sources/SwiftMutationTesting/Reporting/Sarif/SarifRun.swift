struct SarifRun: Sendable, Encodable {
    let tool: SarifTool
    let originalUriBaseIds: [String: SarifArtifactLocation]
    let columnKind: String
    let results: [SarifResult]

    init(tool: SarifTool, originalUriBaseIds: [String: SarifArtifactLocation], results: [SarifResult]) {
        self.tool = tool
        self.originalUriBaseIds = originalUriBaseIds
        columnKind = "utf16CodeUnits"
        self.results = results
    }
}
