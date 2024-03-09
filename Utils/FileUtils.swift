//
//  FileUtils.swift
//  Photoshoot Import
//
//  Created by Clément Mangin on 2024-03-01.
//

import AppKit
import Dependencies
import Foundation
import OrderedCollections
import UniformTypeIdentifiers

extension URL {
    public func mimeType() -> String {
        if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
            return mimeType
        } else {
            return "application/octet-stream"
        }
    }
}

struct FileUtilsClient {
    var searchExecutable: (_ executableName: String) async -> URL?
    var selectFolder: (_ canCreateDirectories: Bool, _ message: String?) async throws -> URL
    var isExecutableFile: (_ path: String) -> Bool
    var listDirectories: (_ atPath: URL) throws -> [URL]
    var findFiles: (_ atPath: URL, _ mimeTypes: [String]?, _ recursive: Bool) throws -> [URL]
    var createDirectory: (_ at: URL) throws -> Void
    var moveFile: (_ at: URL, _ to: URL) throws -> Void
    var copyFile: (_ at: URL, _ to: URL) throws -> Void

    public enum FileUtilsError: Error {
        case enumerationFailed
        case directoryCreationFailed
        case selectionCancelled
    }
}

extension FileUtilsClient: DependencyKey {

    public static var liveValue: Self {

        @MainActor
        func dialog(
            canChooseDirectories: Bool, canChooseFiles: Bool, canCreateDirectories: Bool,
            allowedContentTypes: [UTType]? = nil, message: String? = nil
        ) async throws -> URL {
            let openPanel = NSOpenPanel()
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = canChooseDirectories
            openPanel.canChooseFiles = canChooseFiles
            openPanel.canCreateDirectories = canCreateDirectories
            openPanel.message = message
            if let allowedContentTypes = allowedContentTypes {
                openPanel.allowedContentTypes = allowedContentTypes
            }
            let result = await openPanel.begin()

            guard result == .OK else {
                throw FileUtilsError.selectionCancelled
            }

            return openPanel.urls[0]
        }

        return Self(
            searchExecutable: { executableName in
                let process = Process()
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                process.executableURL = URL(filePath: "/bin/sh")
                // Update environment to make sure that PATH contains the usual suspects
                var environment = ProcessInfo.processInfo.environment
                let path = OrderedSet(environment["PATH"]?.split(separator: ":") ?? [])
                    .union([
                        "/usr/bin", "/bin", "/usr/sbin", "/sbin", "/usr/local/bin",
                        "/opt/homebrew/bin",
                    ])
                environment["PATH"] = path.joined(separator: ":")
                process.environment = environment
                process.arguments = ["-c", "which \(executableName)"]
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    if process.isRunning {
                        process.terminate()
                    }
                    return nil
                }
                guard process.terminationStatus == 0 else {
                    return nil
                }
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                guard !output.isEmpty else {
                    return nil
                }
                return URL(filePath: output)
            },
            selectFolder: { canCreateDirectories, message in
                return try await dialog(
                    canChooseDirectories: true, canChooseFiles: false,
                    canCreateDirectories: canCreateDirectories, message: message)
            },
            isExecutableFile: { path in
                return FileManager.default.isExecutableFile(atPath: path)
            },
            listDirectories: { path in
                let pm = FileManager.default
                return try pm.contentsOfDirectory(
                    at: path, includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                ).filter { url in
                    let fileAttributes = try url.resourceValues(forKeys: [.isDirectoryKey])
                    return fileAttributes.isDirectory ?? false
                }
            },
            findFiles: { path, mimeTypes, recursive in
                let pm = FileManager.default
                let filter: (URL) throws -> Bool = { url in
                    let fileAttributes = try url.resourceValues(forKeys: [
                        .isDirectoryKey, .isRegularFileKey, .isReadableKey,
                    ])
                    return try fileAttributes.isRegularFile ?? false
                        && fileAttributes.isReadable ?? false
                        && mimeTypes?.map { !url.mimeType().matches(of: try Regex($0)).isEmpty }
                            .contains(true)
                            ?? true
                }
                if recursive {
                    guard
                        let enumerator = pm.enumerator(
                            at: path,
                            includingPropertiesForKeys: [
                                .isDirectoryKey, .isRegularFileKey, .creationDateKey,
                                .contentModificationDateKey, .contentAccessDateKey,
                            ],
                            options: [.producesRelativePathURLs, .skipsHiddenFiles],
                            errorHandler: nil)
                    else {
                        throw FileUtilsError.enumerationFailed
                    }
                    return try enumerator.map { return $0 as! URL }.filter(filter)
                } else {
                    let content = try pm.contentsOfDirectory(
                        at: path,
                        includingPropertiesForKeys: [
                            .isDirectoryKey, .isRegularFileKey, .creationDateKey,
                            .contentModificationDateKey, .contentAccessDateKey,
                        ],
                        options: [.producesRelativePathURLs, .skipsHiddenFiles])
                    return try content.filter(filter)
                }
            },
            createDirectory: { path in
                try FileManager.default.createDirectory(
                    at: path, withIntermediateDirectories: true, attributes: nil)
            },
            moveFile: { at, to in
                try FileManager.default.moveItem(at: at, to: to)
            },
            copyFile: { at, to in
                try FileManager.default.copyItem(at: at, to: to)
            }
        )
    }

    public static let testValue = Self(
        searchExecutable: unimplemented("FileUtilsClient.searchExecutable"),
        selectFolder: unimplemented("FileUtilsClient.selectFolder"),
        isExecutableFile: unimplemented("FileUtilsClient.isExecutableFile"),
        listDirectories: unimplemented("FileUtilsClient.listDirectories"),
        findFiles: unimplemented("FileUtilsClient.findFiles"),
        createDirectory: unimplemented("FileUtilsClient.createDirectory"),
        moveFile: unimplemented("FileUtilsClient.moveFile"),
        copyFile: unimplemented("FileUtilsClient.copyFile")
    )
}

extension DependencyValues {
    var fileUtils: FileUtilsClient {
        get { self[FileUtilsClient.self] }
        set { self[FileUtilsClient.self] = newValue }
    }
}
