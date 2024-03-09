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

    func importPhotos(
        srcFolder: URL, destFolder: URL, outputFormat: String, importMode: ImportMode,
        recursive: Bool
    ) async throws -> Int {
        let srcFiles = try self.findFiles(srcFolder, ["image/.+"], recursive)
        let format = try FormatParser.parse(format: outputFormat)

        let filePairs = try FormatParser.prepareImport(
            srcFiles: srcFiles, inSrcFolder: srcFolder, toDestFolder: destFolder,
            withFormat: format, exifMethod: getExifMetadata)

        let importFunction: (_ at: URL, _ to: URL) throws -> Void
        switch importMode {
        case .copy:
            importFunction = copyFile
            break
        case .move:
            importFunction = moveFile
            break
        }

        // Optimization: builds a set of unique folders to create (if any),
        // instead of attempting to create the same folders multiple times
        try Set(filePairs.map { $1.deletingLastPathComponent() }).forEach(createDirectory)

        for (src, dest) in filePairs {
            do {
                try importFunction(src, dest)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                var success = false
                var sequence = 1
                repeat {
                    do {
                        try importFunction(src, dest.append(sequence: sequence))
                        success = true
                    } catch let error as CocoaError where error.code == .fileWriteFileExists {
                        sequence += 1
                    }
                } while !success
            }
        }

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
