import Foundation

enum SystemCalls {

    typealias Kill = @Sendable (pid_t, Int32) -> Int32

    typealias Sysctl = (
        UnsafeMutablePointer<Int32>?, UInt32, UnsafeMutableRawPointer?,
        UnsafeMutablePointer<Int>?, UnsafeMutableRawPointer?, Int
    ) -> Int32
}
