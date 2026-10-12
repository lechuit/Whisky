//
//  WineRuntimeTests.swift
//  Whisky
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import XCTest
@testable import WhiskyKit

final class WineRuntimeTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryRoot)
    }

    private func fixture(loader: String = "wine", server: Bool = true) throws -> URL {
        let root = temporaryRoot.appending(path: "Wine engine ' $test")
        let bin = root.appending(path: "bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        for binary in [loader] + (server ? ["wineserver"] : []) {
            let url = bin.appending(path: binary)
            try "#!/bin/sh\necho wine-11.17\n".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        return root
    }

    private func bottle() throws -> Bottle {
        let root = temporaryRoot.appending(path: "Bottle")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try PropertyListEncoder().encode(BottleSettings()).write(to: root.appending(path: "Metadata.plist"))
        return Bottle(bottleUrl: root)
    }

    func testResolvesWineAndServerFromSameRuntime() throws {
        let root = try fixture()
        let runtime = try WineRuntime(customRoot: root)
        XCTAssertEqual(runtime.wineBinary.path, root.appending(path: "bin/wine").path)
        XCTAssertEqual(runtime.wineserverBinary.path, root.appending(path: "bin/wineserver").path)
        XCTAssertTrue(runtime.isCustom)
    }

    func testResolvesWine64Runtime() throws {
        let runtime = try WineRuntime(customRoot: fixture(loader: "wine64"))
        XCTAssertEqual(runtime.wineBinary.lastPathComponent, "wine64")
    }

    func testRejectsMissingOrNonExecutableComponents() throws {
        XCTAssertThrowsError(try WineRuntime(customRoot: temporaryRoot))
        let root = try fixture(server: false)
        XCTAssertThrowsError(try WineRuntime(customRoot: root))
        let loader = root.appending(path: "bin/wine")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: loader.path)
        XCTAssertThrowsError(try WineRuntime(customRoot: root))
    }

    func testRejectsRuntimeWithExternalWineserverSymlink() throws {
        let root = try fixture(server: false)
        let otherServer = temporaryRoot.appending(path: "other-wineserver")
        try "#!/bin/sh\nexit 0\n".write(to: otherServer, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: otherServer.path)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "bin/wineserver"),
                                                   withDestinationURL: otherServer)
        XCTAssertThrowsError(try WineRuntime(customRoot: root))
    }

    func testRejectsRemoteRoot() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/wine"))
        XCTAssertThrowsError(try WineRuntime(customRoot: url))
    }

    func testExplicitMissingRuntimeNeverFallsBack() throws {
        let bottle = try bottle()
        bottle.settings.customWineRoot = temporaryRoot.appending(path: "removed")
        XCTAssertThrowsError(try Wine.runtime(for: bottle))
        XCTAssertThrowsError(try Wine.killBottle(bottle: bottle))
        XCTAssertThrowsError(try Wine.generateTerminalEnvironmentCommand(bottle: bottle))
        XCTAssertThrowsError(try Wine.generateRunCommand(at: temporaryRoot, bottle: bottle, args: "", environment: [:]))
    }

    func testCustomRuntimeOverridesConflictingWineEnvironment() throws {
        let runtime = try WineRuntime(customRoot: fixture())
        let environment = runtime.environment(merging: ["WINE": "other", "WINESERVER": "other",
                                                       "PATH": "/custom/path", "WINEPREFIX": "/isolated/bottle"])
        XCTAssertEqual(environment["WINE"], runtime.wineBinary.path)
        XCTAssertEqual(environment["WINESERVER"], runtime.wineserverBinary.path)
        XCTAssertEqual(environment["WINEPREFIX"], "/isolated/bottle")
        XCTAssertEqual(environment["PATH"], runtime.binFolder.path + ":/custom/path")
    }

    func testBundledRuntimePreservesExistingEnvironment() {
        let environment = ["WINEPREFIX": "/existing/bottle", "WINEDEBUG": "fixme-all"]
        XCTAssertEqual(WineRuntime.bundled.environment(merging: environment), environment)
    }

    func testDescriptorDefinesExperimentWithoutClaimingSteamAPI() throws {
        let runtime = try WineRuntime(customRoot: fixture())
        let descriptor = runtime.descriptor(id: "wine-devel", displayName: "Wine Devel")
        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(WineRuntimeDescriptor.self, from: data)
        XCTAssertEqual(decoded, descriptor)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.backend, "wine")
        XCTAssertEqual(decoded.wineLoader, "bin/wine")
        XCTAssertEqual(decoded.wineServer, "bin/wineserver")
        XCTAssertEqual(decoded.steamAPI, "unavailable")
    }

    func testOlderMetadataDefaultsToBundledRuntime() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .xml, options: 0)
        let settings = try PropertyListDecoder().decode(BottleSettings.self, from: data)
        XCTAssertNil(settings.customWineRoot)
        XCTAssertEqual(settings.enhancedSync, .msync)
        XCTAssertTrue(settings.dxvkAsync)
    }

    func testCustomMetadataRoundTripKeepsWineVersion() throws {
        let bottle = try bottle()
        bottle.settings.customWineRoot = try fixture()
        bottle.settings.wineVersion = .init(11, 17, 0)
        let metadata = bottle.url.appending(path: "Metadata.plist")
        let settings = try BottleSettings.decode(from: metadata)
        XCTAssertEqual(settings.customWineRoot, bottle.settings.customWineRoot)
        XCTAssertEqual(settings.wineVersion, .init(11, 17, 0))
    }

    func testBundledDXVKCannotBeInjectedIntoCustomBottle() throws {
        let bottle = try bottle()
        bottle.settings.customWineRoot = try fixture()
        XCTAssertThrowsError(try Wine.enableDXVK(bottle: bottle))
        XCTAssertFalse(FileManager.default.fileExists(atPath: bottle.url.appending(path: "drive_c").path))
    }

    func testTerminalEnvironmentHandlesSpecialCharactersInRuntimePath() throws {
        let bottle = try bottle()
        bottle.settings.customWineRoot = try fixture()
        let command = try Wine.generateTerminalEnvironmentCommand(bottle: bottle)
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", command + "\nprintf '%s\\n' \"$WINE\" \"$WINESERVER\" \"$WINEPREFIX\""]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let result = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(process.terminationStatus, 0)
        let runtime = try Wine.runtime(for: bottle)
        let expected = runtime.wineBinary.path + "\n" + runtime.wineserverBinary.path + "\n" + bottle.url.path + "\n"
        XCTAssertEqual(result, expected)
    }
}
