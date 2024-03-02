//
//  ImportPhotoshootView.swift
//  Photoshoot Import
//
//  Created by Clément Mangin on 2024-02-29.
//

import ComposableArchitecture
import SwiftUI

struct ImportPhotoshootView: View {

    @Bindable var store: StoreOf<ImportPhotoshootFeature>

    @State private var importMode: ImportPhotoshootFeature.ImportMode = .copy

    var body: some View {
        Form {
            HStack {
                TextField(
                    "Source folder",
                    text: $store.srcPath
                )
                .disabled(store.jobState == .running)
                Button("Select") {
                    store.send(.srcFolderButtonTapped)
                }
                .disabled(store.jobState == .running)
            }
            HStack {
                TextField(
                    "Destination folder",
                    text: $store.destPath
                ).disabled(store.jobState == .running)
                Button("Select") {
                    store.send(.destFolderButtonTapped)
                }.disabled(store.jobState == .running)
            }
            TextField(
                "Output format",
                text: $store.outputFormat
            )
            .disabled(store.jobState == .running)
            Picker(
                selection: $store.importMode,
                label: Text("Import mode")
            ) {
                Text("Copy").tag(ImportPhotoshootFeature.ImportMode.copy)
                Text("Move").tag(ImportPhotoshootFeature.ImportMode.move)
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .disabled(store.jobState == .running)
            Toggle(
                "Recursive",
                isOn: $store.recursive
            )
            .disabled(store.jobState == .running)
            Button(
                action: {
                    store.send(.importButtonTapped)
                },
                label: {
                    HStack {
                        if store.jobState == .running {
                            ProgressView()
                                .controlSize(.small)
                                .progressViewStyle(.circular)
                                .padding(.trailing)
                        }
                        Text("Import photos")
                    }
                }
            )
            .alert($store.scope(state: \.alert, action: \.alert))
            .disabled(store.jobState != .ready)
            .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
        }
        .padding()
        .frame(width: 500, height: 200, alignment: .topLeading)
    }
}

#Preview {
    ImportPhotoshootView(
        store: Store(initialState: ImportPhotoshootFeature.State()) {
            ImportPhotoshootFeature()
        })
}
