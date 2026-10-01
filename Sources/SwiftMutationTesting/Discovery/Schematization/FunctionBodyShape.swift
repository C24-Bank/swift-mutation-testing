enum FunctionBodyShape: Sendable, Equatable {
    case statements
    case expression
    case conditional(returnsValue: Bool)
}
