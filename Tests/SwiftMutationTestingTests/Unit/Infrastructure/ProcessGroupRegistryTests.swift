import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("ProcessGroupRegistry")
struct ProcessGroupRegistryTests {

    @Test("Given a registered pid, when killAll called, then its whole group receives SIGKILL")
    func killAllSignalsTheGroupOfARegisteredPid() {
        let registry = ProcessGroupRegistry()
        let recorder = RecordingKill()

        registry.register(4242)
        registry.killAll(kill: recorder.asKill)

        #expect(recorder.recorded == [SentSignal(pid: -4242, signal: SIGKILL)])
    }

    @Test("Given a pid deregistered after it exited, when killAll called, then nothing is signalled")
    func aDeregisteredPidIsNotSignalled() {
        let registry = ProcessGroupRegistry()
        let recorder = RecordingKill()

        registry.register(4242)
        registry.deregister(4242)
        registry.killAll(kill: recorder.asKill)

        #expect(recorder.recorded.isEmpty)
    }

    @Test("Given several registered pids, when one is deregistered, then only the others are signalled")
    func deregisteringOnePidKeepsTheOthers() {
        let registry = ProcessGroupRegistry()
        let recorder = RecordingKill()

        registry.register(101)
        registry.register(202)
        registry.register(303)
        registry.deregister(202)
        registry.killAll(kill: recorder.asKill)

        #expect(Set(recorder.recorded.map(\.pid)) == [-101, -303])
    }

    @Test("Given killAll already ran, when it runs again, then no pid is signalled twice")
    func killAllEmptiesTheRegistry() {
        let registry = ProcessGroupRegistry()
        let first = RecordingKill()
        let second = RecordingKill()

        registry.register(4242)
        registry.killAll(kill: first.asKill)
        registry.killAll(kill: second.asKill)

        #expect(first.recorded.count == 1)
        #expect(second.recorded.isEmpty)
    }

    @Test("Given pids of 0 or below, when registered, then they are ignored")
    func nonPositivePidsAreIgnored() {
        let registry = ProcessGroupRegistry()
        let recorder = RecordingKill()

        registry.register(0)
        registry.register(-1)
        registry.deregister(0)
        registry.killAll(kill: recorder.asKill)

        #expect(recorder.recorded.isEmpty)
    }

    @Test("Given a full registry, when another pid is registered, then the tracked pids are still signalled")
    func aFullRegistryKeepsWhatItHas() {
        let registry = ProcessGroupRegistry(capacity: 2)
        let recorder = RecordingKill()

        registry.register(101)
        registry.register(202)
        for pid in pid_t(303) ... 340 {
            registry.register(pid)
        }
        registry.killAll(kill: recorder.asKill)

        #expect(Set(recorder.recorded.map(\.pid)) == [-101, -202])
    }

    @Test("Given concurrent registrations and deregistrations, when they settle, then only the survivors remain")
    func concurrentUpdatesDoNotLosePids() async {
        let registry = ProcessGroupRegistry(capacity: 64)
        let recorder = RecordingKill()

        await withTaskGroup(of: Void.self) { group in
            for pid in pid_t(1) ... 64 {
                group.addTask {
                    registry.register(pid)
                    if pid.isMultiple(of: 2) {
                        registry.deregister(pid)
                    }
                }
            }
        }

        registry.killAll(kill: recorder.asKill)

        let expected = Set(stride(from: pid_t(1), through: 63, by: 2).map { -$0 })
        #expect(Set(recorder.recorded.map(\.pid)) == expected)
    }
}
