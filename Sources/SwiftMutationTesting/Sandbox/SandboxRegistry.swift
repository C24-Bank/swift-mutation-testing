import Foundation
import Synchronization

final class SandboxRegistry: Sendable {

    static let shared = SandboxRegistry()

    deinit {
        take()?.deallocate()
        takeInPlace()?.release()
    }

    func register(_ sandbox: Sandbox) {
        guard !sandbox.isInPlace else {
            let box = Unmanaged.passRetained(InPlaceBox(sandbox)).toOpaque()
            let previous = activeInPlace.exchange(Int(bitPattern: box), ordering: .acquiringAndReleasing)
            UnsafeRawPointer(bitPattern: previous).map { Unmanaged<InPlaceBox>.fromOpaque($0).release() }
            return
        }
        let path = sandbox.rootURL.path
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: path.utf8.count + 1)
        _ = path.withCString { strcpy(buffer, $0) }
        let previous = active.exchange(Int(bitPattern: buffer), ordering: .acquiringAndReleasing)
        UnsafeMutablePointer<CChar>(bitPattern: previous)?.deallocate()
    }

    func deregister() {
        take()?.deallocate()
        takeInPlace()?.release()
    }

    /// Removes a copied sandbox, or writes an in-place sandbox's original files back.
    func cleanup() {
        if let box = takeInPlace() {
            try? box.takeRetainedValue().sandbox.cleanup()
        }
        guard let path = take() else { return }
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: String(cString: path)))
        path.deallocate()
    }

    // MARK: - Private

    private final class InPlaceBox: Sendable {
        init(_ sandbox: Sandbox) { self.sandbox = sandbox }
        let sandbox: Sandbox
    }

    private let active = Atomic<Int>(0)
    private let activeInPlace = Atomic<Int>(0)

    private func take() -> UnsafeMutablePointer<CChar>? {
        UnsafeMutablePointer(bitPattern: active.exchange(0, ordering: .acquiringAndReleasing))
    }

    private func takeInPlace() -> Unmanaged<InPlaceBox>? {
        UnsafeRawPointer(bitPattern: activeInPlace.exchange(0, ordering: .acquiringAndReleasing))
            .map { Unmanaged<InPlaceBox>.fromOpaque($0) }
    }
}
