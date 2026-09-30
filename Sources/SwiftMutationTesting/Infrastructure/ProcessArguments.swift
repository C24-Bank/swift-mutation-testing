import Foundation

enum ProcessArguments {

    static func read(pid: pid_t, sysctl: SystemCalls.Sysctl = Darwin.sysctl) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0

        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)

        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        return parse(Array(buffer.prefix(size)))
    }

    static func parse(_ buffer: [UInt8]) -> [String]? {
        let countSize = MemoryLayout<Int32>.size

        guard buffer.count > countSize else { return nil }

        let count = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        var index = countSize

        while index < buffer.count, buffer[index] != 0 { index += 1 }
        while index < buffer.count, buffer[index] == 0 { index += 1 }

        var arguments: [String] = []

        while arguments.count < count, index < buffer.count {
            let start = index
            while index < buffer.count, buffer[index] != 0 { index += 1 }
            arguments.append(String(bytes: buffer[start ..< index], encoding: .utf8) ?? "")
            index += 1
        }

        return arguments
    }
}
