//
//  ImportPhotoshoot.swift
//  Photoshoot Import
//
//  Created by Clément Mangin on 2024-03-01.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ImportPhotoshootFeature {

    @ObservableState
    struct State: Equatable {
        var srcPath: String = ""
        var destPath: String = ""
        var outputFormat: String = [FormatParser.FormatElement.file(property: .name)].asString
        var importMode: ImportMode = .copy
        var recursive: Bool = true
        var jobState: IngestJobState = .notReady
        @Presents var alert: AlertState<Action.Alert>? = nil
    }

    enum ImportMode {
        case copy
        case move
    }

    @ObservableState
    enum IngestJobState {
        case notReady
        case ready
        case running
    }

    enum Action: BindableAction {
        case binding(BindingAction<ImportPhotoshootFeature.State>)
        case srcFolderButtonTapped
        case srcFolderSelected(path: URL)
        case destFolderButtonTapped
        case destFolderSelected(path: URL)
        case importButtonTapped
        case importJobDone(nbFiles: Int)
        case importJobFailed(Error)
        case alert(PresentationAction<Alert>)
        enum Alert {
            case dismissButtonTapped
        }
    }

    @Dependency(\.fileUtils.selectFolder) var selectFolder
    @Dependency(\.fileUtils.findFiles) var findFiles
    @Dependency(\.fileUtils.createDirectory) var createDirectory
    @Dependency(\.fileUtils.copyFile) var copyFile
    @Dependency(\.fileUtils.moveFile) var moveFile
    @Dependency(\.exiftool.getExifMetadata) var getExifMetadata

    func isReady(_ state: State) -> Bool {
        if !state.srcPath.isEmpty, !state.destPath.isEmpty, !state.outputFormat.isEmpty {
            return true
        } else {
            return false
        }
    }

    private func fetchMetadata(forFiles files: [URL], exifTags: [String]) async throws -> [(
        file: URL, metadata: [String: String]?
    )] {
        return try await withThrowingTaskGroup(of: (file: URL, metadata: [String: String]?).self) {
            [getExifMetadata] taskGroup in
            for file in files {
                taskGroup.addTask(priority: .utility) {
                    let metadata = try getExifMetadata(file, Array(exifTags))
                    return (file: file, metadata: metadata)
                }
            }
            return try await taskGroup.reduce(into: []) { $0.append($1) }
        }
    }

    private func prepareFilePairs(
        filesWithMetadata: [(file: URL, metadata: [String: String]?)],
        format: [FormatParser.FormatElement], destFolder: URL
    ) async -> [(src: URL, dest: URL)] {

        return await withCheckedContinuation { continuation in
            Task(priority: .utility) {
                let formatContainsRelativeSequence = format.contains {
                    switch $0 {
                    case .sequence(type: .local(_)):
                        return true
                    default:
                        return false
                    }
                }
                var fileRanks: [URL: Int] = [:]
                var filePairs: [(src: URL, dest: URL)] = []
                for (index, srcFileWithMetadata) in filesWithMetadata.sorted(by: {
                    $0.file.absoluteString < $1.file.absoluteString
                })
                .enumerated() {
                    let srcFile = srcFileWithMetadata.file
                    let exifMetadata = srcFileWithMetadata.metadata
                    let destFile = FormatParser.format(
                        file: srcFile, exifMetadata: exifMetadata, withFormat: format,
                        absoluteSequenceNumber: index + 1, relativeTo: destFolder)

                    if formatContainsRelativeSequence {
                        let rank = fileRanks[destFile.deletingLastPathComponent(), default: 0] + 1
                        fileRanks[destFile.deletingLastPathComponent()] = rank
                        let sequencedDestFile = FormatParser.format(
                            file: srcFile, exifMetadata: exifMetadata, withFormat: format,
                            absoluteSequenceNumber: index + 1, relativeSequenceNumber: rank,
                            relativeTo: destFolder
                        )
                        filePairs.append((src: srcFile, dest: sequencedDestFile))
                    } else {
                        filePairs.append((src: srcFile, dest: destFile))
                    }
                }
                continuation.resume(returning: filePairs)
            }
        }
    }

    private func prepareImport(
        srcFiles: [URL], inSrcFolder srcFolder: URL, toDestFolder destFolder: URL,
        withFormat format: [FormatParser.FormatElement],
        exifMethod: (_ path: URL, _ tags: [String]) throws -> [String: String]
    ) async throws -> [(src: URL, dest: URL)] {
        let exifTags = Array(format.exifTags())

        // Fetch metadata (or just pretend, if the format doesn't require it)
        let srcFilesWithMetadata: [(file: URL, metadata: [String: String]?)]
        if !exifTags.isEmpty {
            srcFilesWithMetadata = try await fetchMetadata(forFiles: srcFiles, exifTags: exifTags)
        } else {
            srcFilesWithMetadata = srcFiles.map { (file: $0, metadata: nil) }
        }

        // Pair source files with destination files according to the given format
        let filePairs = await prepareFilePairs(
            filesWithMetadata: srcFilesWithMetadata, format: format, destFolder: destFolder)

        return filePairs
    }

    private func importFiles(pairs: [(src: URL, dest: URL)], importMode: ImportMode) async throws {
        let importFunction: (_ at: URL, _ to: URL) throws -> Void
        switch importMode {
        case .copy:
            importFunction = copyFile
            break
        case .move:
            importFunction = moveFile
            break
        }
        return try await withCheckedThrowingContinuation { continuation in
            Task(priority: .utility) {
                // Optimization: builds a set of unique folders to create (if any),
                // instead of attempting to create the same folders multiple times
                try Set(pairs.map { $1.deletingLastPathComponent() }).forEach(createDirectory)

                for (src, dest) in pairs {
                    do {
                        try importFunction(src, dest)
                    } catch let error as CocoaError where error.code == .fileWriteFileExists {
                        var success = false
                        var sequence = 1
                        repeat {
                            do {
                                try importFunction(src, dest.append(sequence: sequence))
                                success = true
                            } catch let error as CocoaError where error.code == .fileWriteFileExists
                            {
                                sequence += 1
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        } while !success
                    }
                }
                continuation.resume()
            }
        }
    }

    private func importPhotos(
        srcFolder: URL, destFolder: URL, outputFormat: String, importMode: ImportMode,
        recursive: Bool
    ) async throws -> Int {
        let srcFiles = try self.findFiles(srcFolder, ["image/.+"], recursive)
        let format = try FormatParser.parse(format: outputFormat)

        let filePairs = try await prepareImport(
            srcFiles: srcFiles, inSrcFolder: srcFolder, toDestFolder: destFolder,
            withFormat: format, exifMethod: getExifMetadata)

        try await importFiles(pairs: filePairs, importMode: importMode)

        return filePairs.count
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                guard state.jobState != .running else { return .none }
                state.jobState = isReady(state) ? .ready : .notReady
                return .none
            case .srcFolderButtonTapped:
                return .run { send in
                    do {
                        let path = try await self.selectFolder(false, nil)
                        await send(.srcFolderSelected(path: path))
                    } catch FileUtilsClient.FileUtilsError.selectionCancelled {
                        // nothing to do
                    }
                }
            case .srcFolderSelected(let path):
                state.srcPath = path.path(percentEncoded: false)
                state.jobState = isReady(state) ? .ready : .notReady
                return .none
            case .destFolderButtonTapped:
                return .run { send in
                    do {
                        let path = try await self.selectFolder(true, nil)
                        await send(.destFolderSelected(path: path))
                    } catch FileUtilsClient.FileUtilsError.selectionCancelled {
                        // nothing to do
                    }
                }
            case .destFolderSelected(let path):
                state.destPath = path.path(percentEncoded: false)
                state.jobState = isReady(state) ? .ready : .notReady
                return .none
            case .importButtonTapped:
                guard !state.srcPath.isEmpty, !state.destPath.isEmpty,
                    !state.outputFormat.isEmpty
                else {
                    return .none
                }
                state.jobState = .running
                return .run { [state = state] send in
                    do {
                        let nbFiles = try await importPhotos(
                            srcFolder: URL(filePath: state.srcPath),
                            destFolder: URL(filePath: state.destPath),
                            outputFormat: state.outputFormat,
                            importMode: state.importMode, recursive: state.recursive)
                        await send(.importJobDone(nbFiles: nbFiles))
                    } catch {
                        await send(.importJobFailed(error))
                    }
                }
            case .importJobDone(let nbFiles):
                state.jobState = .ready
                state.alert = AlertState {
                    TextState("Import completed")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("OK")
                    }
                } message: {
                    TextState("\(nbFiles) files successfully imported.")
                }
                return .none
            case .importJobFailed(let error):
                state.jobState = .ready
                let message: String
                switch error {
                case ExifToolClient.ExifToolClientError.exiftoolNotConfigured:
                    message =
                        "ExifTool is not configured. Please configure ExifTool in the application settings."
                default:
                    message = "An error occurred: \(error)"
                }
                state.alert = AlertState {
                    TextState("Error")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("OK")
                    }
                } message: {
                    TextState(message)
                }
                return .none
            case .alert(.presented(.dismissButtonTapped)):
                return .none
            case .alert(.dismiss):
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
