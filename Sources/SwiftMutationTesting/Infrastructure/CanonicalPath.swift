import Foundation

enum CanonicalPath {

    typealias Resolver = (UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

    static func make(for path: String, resolve: Resolver = { realpath($0, nil) }) -> String {
        path.withCString { pointer in
            guard let resolved = resolve(pointer) else { return path }
            defer { free(resolved) }
            return String(cString: resolved)
        }
    }
}
