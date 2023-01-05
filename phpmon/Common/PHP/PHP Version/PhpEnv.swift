//
//  PhpSwitcher.swift
//  PHP Monitor
//
//  Created by Nico Verbruggen on 21/12/2021.
//  Copyright © 2022 Nico Verbruggen. All rights reserved.
//

import Foundation

class PhpEnv {

    // MARK: - Initializer

    init() {
        self.currentInstall = ActivePhpInstallation()
    }

    func determinePhpAlias() async {
        let brewPhpAlias = await Shell.pipe("\(Paths.brew) info php --json").out

        self.homebrewPackage = try! JSONDecoder().decode(
            [HomebrewPackage].self,
            from: brewPhpAlias.data(using: .utf8)!
        ).first!

        Log.info("[BREW] On your system, the `php` formula means version \(homebrewPackage.version)!")
    }

    // MARK: - Properties

    /** The delegate that is informed of updates. */
    weak var delegate: PhpSwitcherDelegate?

    /** The static app instance. Accessible at any time. */
    static let shared = PhpEnv()

    /** Whether the switcher is busy performing any actions. */
    var isBusy: Bool = false

    /** All available versions of PHP. */
    var availablePhpVersions: [String] = []

    /** Cached information about the PHP installations. */
    var cachedPhpInstallations: [String: PhpInstallation] = [:]

    /** Information about the currently linked PHP installation. */
    var currentInstall: ActivePhpInstallation!

    /**
     The version that the `php` formula via Brew is aliased to on the current system.
     
     If you're up to date, `php` will be aliased to the latest version,
     but that might not be the case since not everyone keeps their
     software up-to-date.
     
     As such, we take that information from Homebrew.
     */
    static var brewPhpAlias: String {
        if Homebrew.fake { return "8.2" }

        return Self.shared.homebrewPackage.version
    }

    /**
     The currently linked and active PHP installation.
     */
    static var phpInstall: ActivePhpInstallation {
        return Self.shared.currentInstall
    }

    /**
     Information we were able to discern from the Homebrew info command.
     */
    var homebrewPackage: HomebrewPackage! = nil

    // MARK: - Methods

    public static var switcher: PhpSwitcher {
        return InternalSwitcher()
    }

    public static func detectPhpVersions() async {
        _ = await Self.shared.detectPhpVersions()
    }

    /**
     Detects which versions of PHP are installed.
     */
    public func detectPhpVersions() async -> [String] {
        let files = await Shell.pipe("ls \(Paths.optPath) | grep php@").out

        var versionsOnly = await extractPhpVersions(
            from: files.components(separatedBy: "\n"),
            supported: Constants.ValetSupportedPhpVersionMatrix[Valet.shared.version.major]!
        )

        // Make sure the aliased version is detected
        // The user may have `php` installed, but not e.g. `php@8.0`
        // We should also detect that as a version that is installed
        let phpAlias = homebrewPackage.version

        // Avoid inserting a duplicate
        if !versionsOnly.contains(phpAlias) && FileSystem.fileExists("\(Paths.optPath)/php/bin/php") {
            versionsOnly.append(phpAlias)
        }

        Log.info("The PHP versions that were detected are: \(versionsOnly)")

        availablePhpVersions = versionsOnly

        var mappedVersions: [String: PhpInstallation] = [:]

        availablePhpVersions.forEach { version in
            mappedVersions[version] = PhpInstallation(version)
        }

        cachedPhpInstallations = mappedVersions

        return versionsOnly
    }

    /**
     Extracts valid PHP versions from an array of strings.
     This array of strings is usually retrieved from `grep`.
     
     If `generateHelpers` is set to true, after detecting
     all versions, helper scripts are generated as well.
     */
    public func extractPhpVersions(
        from versions: [String],
        supported: [String],
        checkBinaries: Bool = true,
        generateHelpers: Bool = true
    ) async -> [String] {
        var output: [String] = []
        versions.filter { (version) -> Bool in
            // Omit everything that doesn't start with php@
            // (e.g. something-php@8.0 won't be detected)
            return version.starts(with: "php@")
        }.forEach { (string) in
            let version = string.components(separatedBy: "php@")[1]
            // Only append the version if it doesn't already exist (avoid dupes),
            // is supported and where the binary exists (avoids broken installs)
            if !output.contains(version)
                && supported.contains(version)
                && (checkBinaries ? FileSystem.fileExists("\(Paths.optPath)/php@\(version)/bin/php") : true) {
                output.append(version)
            }
        }

        if generateHelpers {
            for item in output {
                await PhpHelper.generate(for: item)
            }
        }

        return output
    }

    public func validVersions(for constraint: String) -> [VersionNumber] {
        constraint.split(separator: "|").flatMap {
            return PhpVersionNumberCollection
                .make(from: self.availablePhpVersions)
                .matching(constraint: $0.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /**
     Validates whether the currently running version matches the provided version.
     */
    public func validate(_ version: String) -> Bool {
        if self.currentInstall.version.short == version {
            Log.info("Switching to version \(version) seems to have succeeded. Validation passed.")
            return true
        }

        return false
    }

    /**
     Returns the configuration file instance that is used for a specific config value.
     You can then use the configuration file instance to change values.
     */
    public func getConfigFile(forKey key: String) -> PhpConfigurationFile? {
        return PhpEnv.phpInstall.iniFiles
            .reversed()
            .first(where: { $0.has(key: key) })
    }
}
