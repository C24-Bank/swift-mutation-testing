import Foundation
import Testing

@Suite("Claude Code plugin manifests")
struct PluginManifestTests {
    @Test("Given the marketplace manifest, when read, then it lists this repository as its one plugin")
    func marketplaceListsTheRepositoryAsItsPlugin() throws {
        let marketplace = try jsonObject(at: ".claude-plugin/marketplace.json")
        let plugin = try jsonObject(at: ".claude-plugin/plugin.json")

        let owner = try #require(marketplace["owner"] as? [String: Any])
        let plugins = try #require(marketplace["plugins"] as? [[String: Any]])

        #expect(marketplace["name"] as? String == "swift-mutation-testing")
        #expect(owner["name"] is String)
        #expect(plugins.count == 1)
        #expect(plugins.first?["name"] as? String == plugin["name"] as? String)
        #expect(plugins.first?["source"] as? String == "./")
    }

    @Test("Given the plugin manifest, when read, then it names the plugin in kebab-case and credits an author")
    func pluginManifestHasItsRequiredFields() throws {
        let plugin = try jsonObject(at: ".claude-plugin/plugin.json")

        let name = try #require(plugin["name"] as? String)
        let author = try #require(plugin["author"] as? [String: Any])

        #expect(name.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil)
        #expect((plugin["description"] as? String)?.isEmpty == false)
        #expect(author["name"] is String)
    }

    @Test("Given the manifests, when read, then neither pins a version, so installs follow the repository's commits")
    func noManifestPinsAVersion() throws {
        let marketplace = try jsonObject(at: ".claude-plugin/marketplace.json")
        let plugin = try jsonObject(at: ".claude-plugin/plugin.json")
        let plugins = try #require(marketplace["plugins"] as? [[String: Any]])

        #expect(plugin["version"] == nil)
        #expect(plugins.allSatisfy { $0["version"] == nil })
    }

    @Test("Given the plugin's skill, when its frontmatter is read, then it has the plugin's name and a description")
    func skillFrontmatterNamesTheSkill() throws {
        let plugin = try jsonObject(at: ".claude-plugin/plugin.json")
        let name = try #require(plugin["name"] as? String)
        let skill = try String(contentsOf: repositoryRoot.appending(path: "skills/\(name)/SKILL.md"), encoding: .utf8)

        let lines = skill.components(separatedBy: "\n")
        let end = try #require(lines.dropFirst().firstIndex(of: "---"))
        let frontmatter = lines[1 ..< end]
        let description = frontmatter.first { $0.hasPrefix("description: ") }?.dropFirst("description: ".count)

        #expect(lines.first == "---")
        #expect(frontmatter.contains("name: \(name)"))
        #expect(description?.isEmpty == false)
        #expect((description?.count ?? .max) <= 1_536)
    }

    private var repositoryRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func jsonObject(at relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repositoryRoot.appending(path: relativePath))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
