//
//  BrewCommand.swift
//  PHP Monitor
//
//  Created by Nico Verbruggen on 21/03/2023.
//  Copyright © 2023 Nico Verbruggen. All rights reserved.
//

import Foundation

struct BrewCommandProgress {
    let value: Double
    let title: String
    let description: String

    public static func create(value: Double, title: String, description: String) -> BrewCommandProgress {
        return BrewCommandProgress(value: value, title: title, description: description)
    }
}

protocol BrewCommand {
    func execute(onProgress: @escaping (BrewCommandProgress) -> Void) async throws
}

extension BrewCommand {

}

struct BrewCommandError: Error {
    let error: String
}

class FakeInstallPhpVersionCommand: BrewCommand {
    let version: String

    init(version: String) {
        self.version = version
    }

    func execute(onProgress: @escaping (BrewCommandProgress) -> Void) async throws {
        onProgress(.create(value: 0.2, title: "Hello", description: "Doing the work"))
        await delay(seconds: 2)
        onProgress(.create(value: 0.5, title: "Hello", description: "Doing some more work"))
        await delay(seconds: 1)
        onProgress(.create(value: 1, title: "Hello", description: "Job's done"))
    }
}

class InstallPhpVersionCommand: BrewCommand {
    let formula: String
    let version: String

    init(formula: String) {
        self.version = formula
            .replacingOccurrences(of: "php@", with: "")
            .replacingOccurrences(of: "shivammathur/php/", with: "")
        self.formula = formula
    }

    func execute(onProgress: @escaping (BrewCommandProgress) -> Void) async throws {
        let progressTitle = "Installing PHP \(version)..."

        onProgress(.create(
            value: 0.2,
            title: progressTitle,
            description: "Please wait while Homebrew installs PHP \(version)..."
        ))

        if formula.contains("shivammathur") && !BrewDiagnostics.installedTaps.contains("shivammathur/php") {
            await Shell.quiet("brew tap shivammathur/php")
        }

        let command = """
            export HOMEBREW_NO_INSTALL_UPGRADE=true; \
            export HOMEBREW_NO_INSTALL_CLEANUP=true; \
            brew install \(formula) --force
            """

        let (process, _) = try! await Shell.attach(
            command,
            didReceiveOutput: { text, _ in
                if !text.isEmpty {
                    Log.perf(text)
                }

                // Check if we can recognize any of the typical progress steps
                if let (number, text) = self.reportInstallationProgress(text) {
                    onProgress(.create(value: number, title: progressTitle, description: text))
                }
            },
            withTimeout: .minutes(5)
        )

        if process.terminationStatus <= 0 {
            onProgress(.create(value: 0.95, title: progressTitle, description: "Reloading PHP versions..."))
            await PhpEnv.detectPhpVersions()
            await MainMenu.shared.refreshActiveInstallation()
            onProgress(.create(value: 1, title: progressTitle, description: "The installation has succeeded."))
        } else {
            throw BrewCommandError(error: "The command failed to run correctly.")
        }
    }

    private func reportInstallationProgress(_ text: String) -> (Double, String)? {
        if text.contains("Fetching") {
            return (0.1, text)
        }
        if text.contains("Downloading") {
            return (0.25, text)
        }
        if text.contains("Already downloaded") || text.contains("Downloaded") {
            return (0.50, "Downloaded!")
        }
        if text.contains("Installing") {
            return (0.60, "Installing...")
        }
        if text.contains("Pouring") {
            return (0.80, "Pouring...")
        }
        if text.contains("Summary") {
            return (0.90, "The installation is done!")
        }
        return nil
    }
}

class RemovePhpVersionCommand: Brew {
    // TODO
}
