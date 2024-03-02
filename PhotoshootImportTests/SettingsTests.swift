//
//  SettingsTests.swift
//  PhotoshootImportTests
//
//  Created by Clément Mangin on 2024-03-03.
//

import ComposableArchitecture
import XCTest

@MainActor
final class SettingsTests: XCTestCase {

    func testScreenAppearedSearchExecutable() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.fileUtils.searchExecutable = { _ in
                return URL(filePath: "/usr/local/bin/exiftool")
            }
            $0.exiftool.loadExecutablePath = {
                return nil
            }
            $0.exiftool.setExecutablePath = { _ in }
        }

        await store.send(.screenAppeared)

        await store.receive(\.searchExiftoolRequested)

        await store.receive(\.exiftoolPathUpdated) {
            $0.exiftoolPath = "/usr/local/bin/exiftool"
        }
    }

    func testScreenAppearedLoadExecutable() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.fileUtils.searchExecutable = { _ in
                return URL(filePath: "/usr/local/bin/exiftool")
            }
            $0.exiftool.loadExecutablePath = {
                return "/usr/local/bin/exiftool"
            }
            $0.exiftool.setExecutablePath = { _ in }
        }

        await store.send(.screenAppeared)

        await store.receive(\.exiftoolPathUpdated) {
            $0.exiftoolPath = "/usr/local/bin/exiftool"
        }
    }
}
