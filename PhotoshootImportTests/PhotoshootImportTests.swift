//
//  Photoshoot_ImportTests.swift
//  Photoshoot ImportTests
//
//  Created by Clément Mangin on 2024-02-29.
//

import ComposableArchitecture
import XCTest

final class PhotoshootImportTests: XCTestCase {

    @MainActor
    func testSelectSourceFolder() async {
        let store = TestStore(initialState: ImportPhotoshootFeature.State()) {
            ImportPhotoshootFeature()
        } withDependencies: {
            $0.fileUtils.selectFolder = { _, _ in
                return URL(filePath: "source_folder")
            }
        }

        await store.send(.srcFolderButtonTapped)

        await store.receive(\.srcFolderSelected) {
            $0.srcPath = "source_folder"
        }
    }

    @MainActor
    func testEditSourceFolder() async {
        let store = TestStore(initialState: ImportPhotoshootFeature.State()) {
            ImportPhotoshootFeature()
        }

        await store.send(\.srcPath, "source_folder") {
            $0.srcPath = "source_folder"
        }
    }

    @MainActor
    func testSelectDestinationFolder() async {
        let store = TestStore(initialState: ImportPhotoshootFeature.State()) {
            ImportPhotoshootFeature()
        } withDependencies: {
            $0.fileUtils.selectFolder = { _, _ in
                return URL(filePath: "dest_folder")
            }
        }

        await store.send(.destFolderButtonTapped)

        await store.receive(\.destFolderSelected) {
            $0.destPath = "dest_folder"
        }
    }

    @MainActor
    func testEditDestinationFolder() async {
        let store = TestStore(initialState: ImportPhotoshootFeature.State()) {
            ImportPhotoshootFeature()
        }

        await store.send(\.destPath, "dest_folder") {
            $0.destPath = "dest_folder"
        }
    }

    @MainActor
    func testOutputFormatUpdated() async {
        let store = TestStore(initialState: ImportPhotoshootFeature.State(outputFormat: "")) {
            ImportPhotoshootFeature()
        }

        await store.send(\.outputFormat, "format") {
            $0.outputFormat = "format"
        }
    }

    @MainActor
    func testRecursiveToggleToggled() async {
        let store = TestStore(initialState: ImportPhotoshootFeature.State(recursive: true)) {
            ImportPhotoshootFeature()
        }

        await store.send(\.recursive, false) {
            $0.recursive = false
        }

        await store.send(\.recursive, true) {
            $0.recursive = true
        }
    }

    @MainActor
    func testImportModeChanged() async {
        let store = TestStore(initialState: ImportPhotoshootFeature.State(importMode: .move)) {
            ImportPhotoshootFeature()
        }

        await store.send(\.importMode, .copy) {
            $0.importMode = .copy
        }

        await store.send(\.importMode, .move) {
            $0.importMode = .move
        }
    }

    @MainActor
    func testJobReady() async {
        let store = TestStore(initialState: ImportPhotoshootFeature.State()) {
            ImportPhotoshootFeature()
        }

        await store.send(\.srcPath, "source_folder") {
            $0.srcPath = "source_folder"
        }

        await store.send(\.destPath, "dest_folder") {
            $0.destPath = "dest_folder"
            $0.jobState = .ready
        }
    }

    @MainActor
    func testSrcFolderJobNotReady() async {
        let store = TestStore(
            initialState: ImportPhotoshootFeature.State(
                srcPath: "source_folder",
                destPath: "dest_folder",
                outputFormat: "format",
                jobState: .ready)
        ) {
            ImportPhotoshootFeature()
        }

        await store.send(\.srcPath, "") {
            $0.srcPath = ""
            $0.jobState = .notReady
        }
    }

    @MainActor
    func testDestFolderJobNotReady() async {
        let store = TestStore(
            initialState: ImportPhotoshootFeature.State(
                srcPath: "source_folder",
                destPath: "dest_folder",
                outputFormat: "format",
                jobState: .ready)
        ) {
            ImportPhotoshootFeature()
        }

        await store.send(\.destPath, "") {
            $0.destPath = ""
            $0.jobState = .notReady
        }
    }

    @MainActor
    func testFormatJobNotReady() async {
        let store = TestStore(
            initialState: ImportPhotoshootFeature.State(
                srcPath: "source_folder",
                destPath: "dest_folder",
                outputFormat: "format",
                jobState: .ready)
        ) {
            ImportPhotoshootFeature()
        }

        await store.send(\.outputFormat, "") {
            $0.outputFormat = ""
            $0.jobState = .notReady
        }
    }

    @MainActor
    func testStartJobSuccess() async {
        let store = TestStore(
            initialState: ImportPhotoshootFeature.State(
                srcPath: "source_folder",
                destPath: "dest_folder",
                outputFormat: "format",
                jobState: .ready)
        ) {
            ImportPhotoshootFeature()
        } withDependencies: {
            $0.fileUtils.findFiles = { _, _, _ in
                return []
            }
        }

        await store.send(.importButtonTapped) {
            $0.jobState = .running
        }

        await store.receive(\.importJobDone) {
            $0.jobState = .ready
            $0.alert = AlertState {
                TextState("Import completed")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
            } message: {
                TextState("\(0) files successfully imported.")
            }
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    @MainActor
    func testStartJobError() async {
        let store = TestStore(
            initialState: ImportPhotoshootFeature.State(
                srcPath: "source_folder",
                destPath: "dest_folder",
                outputFormat: "format",
                jobState: .ready)
        ) {
            ImportPhotoshootFeature()
        } withDependencies: {
            $0.fileUtils.findFiles = { _, _, _ in
                throw FileUtilsClient.FileUtilsError.directoryCreationFailed
            }
        }

        await store.send(.importButtonTapped) {
            $0.jobState = .running
        }

        await store.receive(\.importJobFailed) {
            $0.jobState = .ready
            $0.alert = AlertState {
                TextState("Error")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("OK")
                }
            } message: {
                TextState("An error occurred: directoryCreationFailed")
            }
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }
}
