//
//  WineRuntime.swift
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

/// A self-contained macOS Wine installation. Graphics libraries remain the runtime's responsibility.
public struct WineRuntime: Sendable, Equatable {
    public let root: URL
    public let wineBinary: URL
    public let wineserverBinary: URL
    public let isCustom: Bool

    public var binFolder: URL { wineBinary.deletingLastPathComponent() }

    public static var bundled: WineRuntime {
        let root = WhiskyWineInstaller.binFolder.deletingLastPathComponent()
        return WineRuntime(root: root,
                           wineBinary: WhiskyWineInstaller.binFolder.appending(path: "wine64"),
                           wineserverBinary: WhiskyWineInstaller.binFolder.appending(path: "wineserver"),
                           isCustom: false)
    }

    public init(customRoot: URL) throws {
        guard customRoot.isFileURL else { throw WineRuntimeError.invalidRoot }
        let root = customRoot.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { throw WineRuntimeError.invalidRoot }
        let bin = root.appending(path: "bin")
        let candidates = [bin.appending(path: "wine64"), bin.appending(path: "wine")]
        guard let loader = candidates.first(where: Self.isExecutableFile) else {
            throw WineRuntimeError.missingLoader(root.path)
        }
        let server = bin.appending(path: "wineserver")
        guard Self.isExecutableFile(server) else { throw WineRuntimeError.missingServer(root.path) }
        for executable in [loader, server] {
            guard executable.resolvingSymlinksInPath().path.hasPrefix(root.path + "/") else {
                throw WineRuntimeError.componentOutsideRoot(executable.path)
            }
        }
        self.init(root: root, wineBinary: loader, wineserverBinary: server, isCustom: true)
    }

    private init(root: URL, wineBinary: URL, wineserverBinary: URL, isCustom: Bool) {
        self.root = root
        self.wineBinary = wineBinary
        self.wineserverBinary = wineserverBinary
        self.isCustom = isCustom
    }

    private static func isExecutableFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue && FileManager.default.isExecutableFile(atPath: url.path)
    }

    /// Ensure subprocesses use this loader and server rather than a runtime elsewhere in PATH.
    public func environment(merging environment: [String: String]) -> [String: String] {
        guard isCustom else { return environment }
        var result = environment
        result["WINE"] = wineBinary.path
        result["WINESERVER"] = wineserverBinary.path
        let searchPath = environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        result["PATH"] = binFolder.path + ":" + searchPath
        return result
    }

    public func descriptor(id: String, displayName: String) -> WineRuntimeDescriptor {
        WineRuntimeDescriptor(schemaVersion: 1, id: id, displayName: displayName, backend: "wine",
                              root: root.path, wineLoader: "bin/" + wineBinary.lastPathComponent,
                              wineServer: "bin/" + wineserverBinary.lastPathComponent, steamAPI: "unavailable")
    }
}

public struct WineRuntimeDescriptor: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let id: String
    public let displayName: String
    public let backend: String
    public let root: String
    public let wineLoader: String
    public let wineServer: String
    public let steamAPI: String
}

public enum WineRuntimeError: LocalizedError {
    case invalidRoot
    case missingLoader(String)
    case missingServer(String)
    case componentOutsideRoot(String)
    case bundledDXVKWithCustomRuntime

    public var errorDescription: String? {
        switch self {
        case .invalidRoot:
            return "Select a local Wine runtime folder containing bin/wine (or bin/wine64) and bin/wineserver."
        case .missingLoader(let root):
            return "No executable bin/wine or bin/wine64 was found in \(root)."
        case .missingServer(let root):
            return "No executable bin/wineserver was found in \(root)."
        case .componentOutsideRoot(let path):
            return "Wine executable resolves outside the selected runtime: \(path)."
        case .bundledDXVKWithCustomRuntime:
            return "Whisky's bundled DXVK is not installed into custom runtime bottles. Configure graphics separately."
        }
    }
}
