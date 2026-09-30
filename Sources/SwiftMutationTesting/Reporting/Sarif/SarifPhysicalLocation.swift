struct SarifPhysicalLocation: Sendable, Encodable {
    let artifactLocation: SarifArtifactLocation
    let region: SarifRegion
}
