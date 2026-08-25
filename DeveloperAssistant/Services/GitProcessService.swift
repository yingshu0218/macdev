import Foundation

struct GitProcessService: Sendable {
    struct Result: Sendable { let output: String; let status: Int32 }

    func run(arguments: [String], directory: URL, token: String? = nil, account: String = "git") async throws -> Result {
        try await Task.detached {
            let process = Process(); let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments; process.currentDirectoryURL = directory
            process.standardOutput = pipe; process.standardError = pipe
            var environment = ProcessInfo.processInfo.environment
            var askpassURL: URL?
            if let token {
                let url = FileManager.default.temporaryDirectory.appending(path: "developer-assistant-askpass-\(UUID().uuidString)")
                let script = "#!/bin/sh\ncase \"$1\" in *Username*) printf '%s' \"$DA_GIT_ACCOUNT\" ;; *) printf '%s' \"$DA_GIT_TOKEN\" ;; esac\n"
                try script.write(to: url, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
                askpassURL = url; environment["GIT_ASKPASS"] = url.path; environment["GIT_TERMINAL_PROMPT"] = "0"; environment["DA_GIT_TOKEN"] = token; environment["DA_GIT_ACCOUNT"] = account
            }
            process.environment = environment
            defer { if let askpassURL { try? FileManager.default.removeItem(at: askpassURL) } }
            try process.run(); process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return Result(output: String(decoding: data, as: UTF8.self), status: process.terminationStatus)
        }.value
    }
}
