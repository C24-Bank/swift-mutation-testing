import Foundation

/// A copy of the scheme that lists only the pinned test plan and that plan's testables.
///
/// `build-for-testing` builds every testable in a scheme, whichever plan is selected, so an app
/// scheme with snapshot or UI test targets builds them for every mutation run. The copy is written
/// as a user scheme next to the project and removed again with `removeAll(in:)`.
enum DerivedScheme {
    static let suffix = "-Mutation"

    static func prepare(in root: URL, scheme: String) -> String {
        guard let plan = ProcessInfo.processInfo.environment["SMT_TEST_PLAN"], !plan.isEmpty,
            let project = xcodeproj(in: root),
            let source = try? String(
                contentsOf: project.appendingPathComponent("xcshareddata/xcschemes/\(scheme).xcscheme"),
                encoding: .utf8
            ),
            let derived = derive(scheme: source, plan: plan, root: root)
        else { return scheme }

        let name = scheme + suffix
        let directory = userSchemesDirectory(in: project)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try derived.write(to: directory.appendingPathComponent("\(name).xcscheme"), atomically: true, encoding: .utf8)
        } catch {
            return scheme
        }
        return name
    }

    static func removeAll(in root: URL) {
        guard let project = xcodeproj(in: root) else { return }
        let directory = userSchemesDirectory(in: project)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where file.hasSuffix("\(suffix).xcscheme") {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    static func derive(scheme: String, plan: String, root: URL) -> String? {
        let planReferences = matches(of: #"<TestPlanReference\b.*?</TestPlanReference>"#, in: scheme)
        guard let reference = planReferences.first(where: {
                $0.contains("/\(plan).xctestplan\"") || $0.contains(":\(plan).xctestplan\"")
            }),
            let containerPath = firstCapture(of: #"reference\s*=\s*"container:([^"]+)""#, in: reference),
            let planTargets = testTargets(ofPlanAt: root.appendingPathComponent(containerPath)),
            let plansBlock = matches(of: #"<TestPlans>.*?</TestPlans>"#, in: scheme).first
        else { return nil }

        var derived = scheme.replacingOccurrences(of: plansBlock, with: """
            <TestPlans>
                     <TestPlanReference
                        reference = "container:\(containerPath)"
                        default = "YES">
                     </TestPlanReference>
                  </TestPlans>
            """)

        for testable in matches(of: #"\s*<TestableReference\b.*?</TestableReference>"#, in: derived) {
            guard let name = firstCapture(of: #"BlueprintName\s*=\s*"([^"]*)""#, in: testable),
                planTargets.contains(name) == false
            else { continue }
            derived = derived.replacingOccurrences(of: testable, with: "")
        }

        return derived
    }

    private static func testTargets(ofPlanAt url: URL) -> Set<String>? {
        guard let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let targets = json["testTargets"] as? [[String: Any]]
        else { return nil }

        return Set(targets.compactMap { ($0["target"] as? [String: Any])?["name"] as? String })
    }

    private static func xcodeproj(in root: URL) -> URL? {
        let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return items.first { $0.pathExtension == "xcodeproj" }
    }

    private static func userSchemesDirectory(in project: URL) -> URL {
        let user = ProcessInfo.processInfo.environment["USER"] ?? NSUserName()
        return project.appendingPathComponent("xcuserdata/\(user).xcuserdatad/xcschemes")
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    private static func firstCapture(of pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
