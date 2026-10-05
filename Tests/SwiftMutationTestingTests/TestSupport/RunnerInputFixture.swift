@testable import SwiftMutationTesting

func makeRunnerInput(
    projectPath: String = "/tmp",
    projectType: ProjectType = .xcode(scheme: "MyScheme", destination: "platform=macOS"),
    timeout: Double = 60,
    concurrency: Int = 1,
    noCache: Bool = false,
    schematizedFiles: [SchematizedFile] = [],
    mutants: [MutantDescriptor] = []
) -> RunnerInput {
    RunnerInput(
        projectPath: projectPath,
        projectType: projectType,
        timeout: timeout,
        concurrency: concurrency,
        noCache: noCache,
        schematizedFiles: applied(schematizedFiles, for: mutants),
        mutants: mutants
    )
}

func applied(_ files: [SchematizedFile], for mutants: [MutantDescriptor]) -> [SchematizedFile] {
    files.map { file in
        var content = file.schematizedContent
        let ids = mutants.filter { $0.isSchematizable && $0.filePath == file.originalPath }.map(\.id)
        let unlabeled = ids.filter { !content.contains("case \"\($0)\":") }

        if !unlabeled.isEmpty {
            content += "\n" + unlabeled.map { "// case \"\($0)\":" }.joined(separator: "\n")
        }
        let support = SupportDeclarations.perFile(for: file.originalPath)
        if !content.contains(support) {
            let imported = content.contains("import Foundation")
            content += (imported ? "" : "\n\n" + SupportDeclarations.importLine(.implicit)) + "\n\n" + support + "\n"
        }

        return SchematizedFile(originalPath: file.originalPath, schematizedContent: content)
    }
}
