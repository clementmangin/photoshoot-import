//
//  URLExtensionsTests.swift
//  PhotoshootImportTests
//
//  Created by Clément Mangin on 2024-03-09.
//

import XCTest

final class URLExtensionsTests: XCTestCase {

    func testURLAppend() {
        // File with extension
        XCTAssertEqual(
            URL(filePath: "folder/file.jpeg").append(sequence: 10),
            URL(filePath: "folder/file 10.jpeg")
        )

        // File with no extension
        XCTAssertEqual(
            URL(filePath: "folder/file").append(sequence: 10),
            URL(filePath: "folder/file 10")
        )

        // File with base path
        XCTAssertEqual(
            URL(filePath: "folder/file.jpeg", relativeTo: URL(filePath: "/Users/user/")).append(
                sequence: 10),
            URL(filePath: "folder/file 10.jpeg", relativeTo: URL(filePath: "/Users/user/"))
        )
    }
}
