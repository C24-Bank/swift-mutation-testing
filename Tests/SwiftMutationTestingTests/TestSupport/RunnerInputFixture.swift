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
        schematizedFiles: schematizedFiles,
        mutants: mutants
    )
}
