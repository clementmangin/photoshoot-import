//
//  ExifTool.swift
//  Photoshoot Import
//
//  Created by Clément Mangin on 2024-03-01.
//

import Dependencies
import ExifTool
import Foundation

struct ExifToolClient {

    public static let exiftoolPathSettingKey = "exiftoolPathSettingKey"

    enum ExifToolClientError: Error {
        case exiftoolNotConfigured
        case exiftoolNotFound
        case fileDoesNotExist
    }

    var getExifMetadata: (_ path: URL, _ tags: [String]) throws -> [String: String]
    var loadExecutablePath: () -> String?
    var setExecutablePath: (_ executablePath: String) -> Void
}

extension ExifToolClient: DependencyKey {
    public static var liveValue: Self {
        let getExecutablePath: () -> String? = {
            if let exiftoolPath = UserDefaults.standard.string(
                forKey: ExifToolClient.exiftoolPathSettingKey)
            {
                ExifTool.setExifTool(exiftoolPath)
                return exiftoolPath
            }
            return nil
        }
        return Self(
            getExifMetadata: { path, tags in
                guard getExecutablePath() != nil else {
                    throw ExifToolClient.ExifToolClientError.exiftoolNotConfigured
                }
                let exif = ExifTool.read(fromurl: path, tags: tags)
                return exif.metadata
            },
            loadExecutablePath: getExecutablePath,
            setExecutablePath: { executablePath in
                UserDefaults.standard.setValue(
                    executablePath,
                    forKey: ExifToolClient.exiftoolPathSettingKey)
                ExifTool.setExifTool(executablePath)
            }
        )
    }

    public static let testValue = Self(
        getExifMetadata: unimplemented("ExifToolClient.getExifMetadata"),
        loadExecutablePath: unimplemented("ExifToolClient.getExecutablePath"),
        setExecutablePath: unimplemented("ExifToolClient.setExecutablePath")
    )
}

extension DependencyValues {
    var exiftool: ExifToolClient {
        get { self[ExifToolClient.self] }
        set { self[ExifToolClient.self] = newValue }
    }
}
