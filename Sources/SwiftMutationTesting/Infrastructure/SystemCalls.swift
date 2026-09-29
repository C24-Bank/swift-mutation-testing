import Foundation

enum SystemCalls {

    typealias Kill = @Sendable (pid_t, Int32) -> Int32
}
