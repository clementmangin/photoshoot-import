//
//  Settings.swift
//  Photoshoot Import
//
//  Created by Clément Mangin on 2024-03-01.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var exiftoolPath: String = ""
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<SettingsFeature.State>)
        case screenAppeared
        case exiftoolPathUpdated(path: String)
        case searchExiftoolButtonTapped
        case searchExiftoolRequested(userRequested: Bool)
        case exiftoolFound(path: String, userRequested: Bool)
        case exiftoolNotFound
    }

    @Dependency(\.fileUtils.searchExecutable) var searchExecutable
    @Dependency(\.exiftool.loadExecutablePath) var getExiftoolPath
    @Dependency(\.exiftool.setExecutablePath) var setExiftoolPath

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.exiftoolPath):
                setExiftoolPath(state.exiftoolPath)
                return .none
            case .screenAppeared:
                return .run { send in
                    if let exiftoolPath = getExiftoolPath() {
                        await send(.exiftoolPathUpdated(path: exiftoolPath))
                    } else {
                        await send(.searchExiftoolRequested(userRequested: false))
                    }
                }
            case .searchExiftoolButtonTapped:
                return .run { send in
                    await send(.searchExiftoolRequested(userRequested: true))
                }
            case .searchExiftoolRequested(userRequested: _):
                return .run { send in
                    let path = await searchExecutable("exiftool")
                    if let path = path {
                        await send(.exiftoolPathUpdated(path: path.path()))
                    } else {
                        await send(.exiftoolNotFound)
                    }
                }
            case .exiftoolFound(let path, userRequested: _):
                return .run { send in
                    await send(.exiftoolPathUpdated(path: path))
                }
            case .exiftoolPathUpdated(let path):
                state.exiftoolPath = path
                setExiftoolPath(path)
                return .none
            case .exiftoolNotFound:
                return .none
            default:
                return .none
            }
        }
    }
}
