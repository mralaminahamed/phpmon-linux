//
//  PhpSwitcher.swift
//  PHP Monitor
//
//  Created by Nico Verbruggen on 21/12/2021.
//  Copyright © 2021 Nico Verbruggen. All rights reserved.
//

import Foundation

protocol PhpSwitcherDelegate: AnyObject {
    func switcherDidStartSwitching()
    func switcherDidCompleteSwitch()
}

class PhpSwitcher {
    
    // MARK: - Initializer
    
    init() {
        self.currentInstall = ActivePhpInstallation()
        
        let brewPhpAlias = Shell.pipe("\(Paths.brew) info php --json");
        
        self.homebrewPackage = try! JSONDecoder().decode(
            [HomebrewPackage].self,
            from: brewPhpAlias.data(using: .utf8)!
        ).first!
        
        print("When on your system, the `php` formula means version \(homebrewPackage.version)!")
    }
    
    // MARK: - Properties
    
    /** The delegate that is informed of updates. */
    weak var delegate: PhpSwitcherDelegate?

    /** The static app instance. Accessible at any time. */
    static let shared = PhpSwitcher()
    
    /** Whether the switcher is busy performing any actions. */
    var isBusy: Bool = false
    
    /** All available versions of PHP. */
    var availablePhpVersions: [String] = []
    
    /** Cached information about the PHP installations. */
    var cachedPhpInstallations: [String: PhpInstallation] = [:]
    
    /** Information about the currently linked PHP installation. */
    var currentInstall: ActivePhpInstallation
    
    /**
     The version that the `php` formula via Brew is aliased to on the current system.
     
     If you're up to date, `php` will be aliased to the latest version,
     but that might not be the case since not everyone keeps their
     software up-to-date.
     
     As such, we take that information from Homebrew.
     */
    static var brewPhpVersion: String {
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
    
    public static func detectPhpVersions() -> Void {
        _ = Self.shared.detectPhpVersions()
    }
    
    /**
     Detects which versions of PHP are installed.
     */
    public func detectPhpVersions() -> [String]
    {
        let files = Shell.pipe("ls \(Paths.optPath) | grep php@")
        
        var versionsOnly = extractPhpVersions(from: files.components(separatedBy: "\n"))
        
        // Make sure the aliased version is detected
        // The user may have `php` installed, but not e.g. `php@8.0`
        // We should also detect that as a version that is installed
        let phpAlias = homebrewPackage.version
        
        // Avoid inserting a duplicate
        if (!versionsOnly.contains(phpAlias) && Shell.fileExists("\(Paths.optPath)/php/bin/php")) {
            versionsOnly.append(phpAlias)
        }
        
        print("The PHP versions that were detected are: \(versionsOnly)")
        
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
     */
    public func extractPhpVersions(
        from versions: [String],
        checkBinaries: Bool = true
    ) -> [String] {
        var output : [String] = []
        
        versions.filter { (version) -> Bool in
            // Omit everything that doesn't start with php@
            // (e.g. something-php@8.0 won't be detected)
            return version.starts(with: "php@")
        }.forEach { (string) in
            let version = string.components(separatedBy: "php@")[1]
            // Only append the version if it doesn't already exist (avoid dupes),
            // is supported and where the binary exists (avoids broken installs)
            if !output.contains(version)
                && Constants.SupportedPhpVersions.contains(version)
                && (checkBinaries ? Shell.fileExists("\(Paths.optPath)/php@\(version)/bin/php") : true)
            {
                output.append(version)
            }
        }
        
        return output
    }
}
