//
//  PhotoshootImportApp.swift
//  Photoshoot Import
//
//  Created by Clément Mangin on 2024-02-29.
//

import ComposableArchitecture
import SwiftUI

@main
struct PhotoshootImportApp: App {

    @Dependency(\.fileUtils.searchExecutable) var searchExecutable
    @Dependency(\.exiftool.loadExecutablePath) var loadExecutablePath
    @Dependency(\.exiftool.setExecutablePath) var setExiftoolPath

    var body: some Scene {
        WindowGroup {
            ImportPhotoshootView(
                store: Store(initialState: ImportPhotoshootFeature.State()) {
                    ImportPhotoshootFeature()
                }
            )
            .fixedSize()
            .task(priority: .background) {
                // Search for exiftool at startup if not already configured
                if loadExecutablePath() == nil {
                    if let exiftoolPath = await searchExecutable("exiftool") {
                        setExiftoolPath(exiftoolPath.path(percentEncoded: false))
                    }
                }
            }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Photoshoot Import") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string:
                                    """
                                    Credits:\n \
                                    ExifTool: © Phil Harvey\n \
                                    ExifTool Swift: © Hervé Lemai\n \
                                    Composable Architecture: © Point-Free, Inc.
                                    """,
                                attributes: [
                                    .font: NSFont.systemFont(
                                        ofSize: NSFont.smallSystemFontSize),
                                    .paragraphStyle: {
                                        let paragraphStyle = NSMutableParagraphStyle()
                                        paragraphStyle.alignment = NSTextAlignment.center
                                        return paragraphStyle
                                    }(),
                                ]
                            ),
                            NSApplication.AboutPanelOptionKey(
                                rawValue: "Copyright"
                            ): "Copyright © 2024 Clément Mangin",
                        ]
                    )
                }
            }
        }
        #if os(macOS)
            Settings {
                SettingsView(
                    store: Store(initialState: SettingsFeature.State()) {
                        SettingsFeature()
                    })
            }
        #endif
    }
}
