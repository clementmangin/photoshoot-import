//
//  URLExtensions.swift
//  PhotoshootImport
//
//  Created by Clément Mangin on 2024-03-09.
//

import Foundation

extension URL {
    func append(sequence: Int) -> URL {
        return URL(
            filePath:
                "\(self.deletingPathExtension().path()) \(sequence)\(self.pathExtension.isEmpty ? "" : ".\(self.pathExtension)")",
            relativeTo: self.baseURL
        )
    }
}
