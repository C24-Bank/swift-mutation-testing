/// What a result file says about where it came from: the plan it ran and, for a slice of it, the shard.
/// `merge` joins only results of one plan, and every run has one, written down or not.
struct RunIdentity: Sendable, Equatable {
    let planSha256: String
    let shard: Shard?
}
