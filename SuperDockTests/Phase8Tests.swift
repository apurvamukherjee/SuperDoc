import Foundation
import Testing

private let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

struct JSONPathTests {
    private func json() throws -> Any {
        try JSONSerialization.jsonObject(with: Data("""
            {"bitcoin": {"usd": 63700.5}, "hits": [{"title": "A", "url": "https://a"}, {"title": "B"}],
             "list": [[1, 2], [3]], "odd key": 7, "nothing": null}
            """.utf8))
    }

    @Test(arguments: [
        ("$.bitcoin.usd", [63700.5] as [Double]),
        ("$['odd key']", [7]),
        ("$.list[0][1]", [2]),
        ("$.list[*][0]", [1, 3])
    ])
    func numbers(path: String, expected: [Double]) throws {
        #expect(JSONPath.values(path, in: try json()).compactMap { ($0 as? NSNumber)?.doubleValue } == expected)
    }

    @Test func wildcardSkipsMissingFields() throws {
        #expect(JSONPath.values("$.hits[*].title", in: try json()).map { "\($0)" } == ["A", "B"])
        #expect(JSONPath.values("$.hits[*].url", in: try json()).count == 1)
    }

    @Test(arguments: ["$.missing", "$.hits[9]", "$.nothing", "bitcoin.usd", "$.bitcoin.", "$[x]"])
    func badOrMissingPathsSelectNothing(path: String) throws {
        #expect(JSONPath.values(path, in: try json()).isEmpty)
    }
}

struct PluginManifestTests {
    @Test func placeholdersAreFilledAndEncodedForURLs() {
        let values = ["repo": "a b/c", "to": "EUR"]
        #expect(PluginTemplate.fill("https://x/{repo}?to={to}", with: values, encode: true) == "https://x/a%20b/c?to=EUR")
        #expect(PluginTemplate.fill("$.rates.{to}", with: values) == "$.rates.EUR")
    }

    @Test func formatting() {
        #expect(PluginTemplate.format(NSNumber(value: 1234.5), as: .number) == 1234.5.formatted())
        #expect(PluginTemplate.format(NSNumber(value: 42), as: .percent) == (0.42).formatted(.percent.precision(.fractionLength(0...1))))
        #expect(PluginTemplate.format("hello", as: nil) == "hello")
        #expect(PluginTemplate.format(nil, as: .number) == "–")
    }

    @Test func validationRejectsInsecureOrIncompletePlugins() throws {
        let base = #"{"id":"x","name":"X","source":{"url":"https://a"},"tile":{"template":"value","value":"$.v"}}"#
        try JSONDecoder().decode(PluginManifest.self, from: Data(base.utf8)).validate()
        let http = base.replacingOccurrences(of: "https://a", with: "http://a")
        #expect(throws: PluginManifest.Problem.insecureURL) {
            try JSONDecoder().decode(PluginManifest.self, from: Data(http.utf8)).validate()
        }
        let noValue = base.replacingOccurrences(of: #","value":"$.v""#, with: "")
        #expect(throws: PluginManifest.Problem.missingValuePath) {
            try JSONDecoder().decode(PluginManifest.self, from: Data(noValue.utf8)).validate()
        }
    }

    @Test func intervalHasAFloor() throws {
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(
            #"{"id":"x","name":"X","source":{"url":"https://a","every":5},"tile":{"template":"text","value":"$"}}"#.utf8))
        #expect(manifest.interval == 60)
    }

    /// Every plugin that ships with the app or sits in the gallery must load.
    @Test func bundledAndGalleryPluginsAreValid() throws {
        let folders = [repo.appending(path: "SuperDock/Resources/Plugins"), repo.appending(path: "gallery/plugins")]
        let files = try folders.flatMap { try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }
            .filter { $0.pathExtension == "json" }
        #expect(files.count >= 17)
        for file in files {
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: file))
            try manifest.validate()
        }
        let indexData = try Data(contentsOf: repo.appending(path: "gallery/index.json"))
        let index = try JSONSerialization.jsonObject(with: indexData) as? [[String: String]]
        for entry in index ?? [] {
            #expect(FileManager.default.fileExists(atPath: repo.appending(path: "gallery/\(entry["file"] ?? "")").path))
        }
    }
}

struct BundledListPluginTests {
    @Test(arguments: [("hackernews", "$.hits[*].points"), ("lobsters", "$[*].score"), ("dev", "$[*].public_reactions_count")])
    func listPluginsShowCounts(name: String, counts: String) throws {
        let file = repo.appending(path: "SuperDock/Resources/Plugins/plugin-\(name).json")
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: file))
        #expect(manifest.tile.counts == counts)
    }
}

struct DevParsingTests {
    @Test func lsofListeningPorts() {
        let output = """
            COMMAND   PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
            node    123 me   23u  IPv4 0x1      0t0  TCP 127.0.0.1:5173 (LISTEN)
            node    123 me   24u  IPv6 0x2      0t0  TCP [::1]:5173 (LISTEN)
            Python  456 me    5u  IPv4 0x3      0t0  TCP *:8000 (LISTEN)
            """
        #expect(DevParsing.listeningPorts(fromLsof: output) == [.init(port: 5173, process: "node"), .init(port: 8000, process: "Python")])
    }

    @Test func gitStatus() {
        let status = DevParsing.gitStatus(fromPorcelain: "## main...origin/main [ahead 2, behind 1]\n M a.swift\n?? b.swift\n")
        #expect(status == .init(branch: "main", changed: 2, ahead: 2, behind: 1))
        #expect(DevParsing.gitStatus(fromPorcelain: "## No commits yet on dev\n")?.branch == "dev")
        #expect(DevParsing.gitStatus(fromPorcelain: "fatal: not a git repository") == nil)
    }

    @Test func lastCommit() {
        let commit = DevParsing.lastCommit(fromLog: "a1b2c3d\u{1f}1795109100\u{1f}Fix: keep | and : in subjects\n")
        #expect(commit == .init(hash: "a1b2c3d", date: Date(timeIntervalSince1970: 1_795_109_100),
                                subject: "Fix: keep | and : in subjects"))
        #expect(DevParsing.lastCommit(fromLog: "a1b2c3d\u{1f}1795109100\u{1f}\n")?.subject == "")
        #expect(DevParsing.lastCommit(fromLog: "") == nil)
        #expect(DevParsing.lastCommit(fromLog: "a1b2c3d\u{1f}yesterday\u{1f}Subject") == nil)
        #expect(DevParsing.lastCommit(fromLog: "fatal: your current branch 'main' does not have any commits yet") == nil)
    }

    @Test func lineChanges() {
        let both = DevParsing.lineChanges(fromShortstat: " 3 files changed, 142 insertions(+), 37 deletions(-)\n")
        #expect(both.insertions == 142 && both.deletions == 37)
        let added = DevParsing.lineChanges(fromShortstat: " 1 file changed, 1 insertion(+)\n")
        #expect(added.insertions == 1 && added.deletions == 0)
        let removed = DevParsing.lineChanges(fromShortstat: " 2 files changed, 9 deletions(-)\n")
        #expect(removed.insertions == 0 && removed.deletions == 9)
        let clean = DevParsing.lineChanges(fromShortstat: "")
        #expect(clean.insertions == 0 && clean.deletions == 0)
    }

    @Test func passwordsUseTheAlphabetAndLength() {
        let password = DevParsing.password(length: 24)
        #expect(password.count == 24)
        #expect(password.allSatisfy(DevParsing.passwordAlphabet.contains))
        #expect(DevParsing.password(length: 24) != password)
    }
}
