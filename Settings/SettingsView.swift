//
//  SettingsView.swift
//  Photoshoot Import
//
//  Created by Clément Mangin on 2024-03-01.
//

import ComposableArchitecture
import SwiftUI

struct SettingsView: View {

    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        Form {
            HStack {
                TextField(
                    "Exiftool path",
                    text: $store.exiftoolPath
                )
                Button(
                    action: {
                        store.send(.searchExiftoolButtonTapped)
                    },
                    label: {
                        Text("Guess")
                    })
            }
        }
        .padding()
        .frame(width: 500, height: 100)
        .onAppear {
            store.send(.screenAppeared)
        }
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        })
}
