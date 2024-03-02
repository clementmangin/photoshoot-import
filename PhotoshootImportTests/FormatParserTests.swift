//
//  FormatParserTests.swift
//  PhotoshootImportTests
//
//  Created by Clément Mangin on 2024-03-02.
//

import XCTest

final class FormatParserTests: XCTestCase {

    func testSplitFolder() throws {
        XCTAssertEqual(
            FormatParser.splitFolders(forPath: "folder/subfolder/file"),
            [
                .constant(value: "folder"),
                .pathSeparator,
                .constant(value: "subfolder"),
                .pathSeparator,
                .constant(value: "file"),
            ])
        XCTAssertEqual(
            FormatParser.splitFolders(forPath: "folder//file"),
            [
                .constant(value: "folder"),
                .pathSeparator,
                .constant(value: ""),
                .pathSeparator,
                .constant(value: "file"),
            ])
        XCTAssertEqual(
            FormatParser.splitFolders(forPath: "/folder/"),
            [
                .constant(value: ""),
                .pathSeparator,
                .constant(value: "folder"),
                .pathSeparator,
                .constant(value: ""),
            ])
    }

    func testParseFormat() throws {
        XCTAssertEqual(
            try FormatParser.parse(format: "#invalid# - #exif:DateTimeOriginal# {} #file:ext#.jpg"),
            [
                .constant(value: "#invalid# - "),
                .exif(property: .property(tag: "DateTimeOriginal")),
                .constant(value: " {} "),
                .file(property: .ext),
                .constant(value: ".jpg"),
            ])
        XCTAssertEqual(
            try FormatParser.parse(format: "#exif:DateTimeOriginal# {} #file:ext#.jpg"),
            [
                .exif(property: .property(tag: "DateTimeOriginal")),
                .constant(value: " {} "),
                .file(property: .ext),
                .constant(value: ".jpg"),
            ])
        XCTAssertEqual(
            try FormatParser.parse(format: "#invalid# - #exif:DateTimeOriginal# {} #file:ext#"),
            [
                .constant(value: "#invalid# - "),
                .exif(property: .property(tag: "DateTimeOriginal")),
                .constant(value: " {} "),
                .file(property: .ext),
            ])
        XCTAssertEqual(
            try FormatParser.parse(format: "#exif:DateTimeOriginal# {} #file:ext#"),
            [
                .exif(property: .property(tag: "DateTimeOriginal")),
                .constant(value: " {} "),
                .file(property: .ext),
            ])
        XCTAssertEqual(
            try FormatParser.parse(format: "#exif:DateTimeOriginal#/#file:name#"),
            [
                .exif(property: .property(tag: "DateTimeOriginal")),
                .pathSeparator,
                .file(property: .name),
            ])
        XCTAssertEqual(
            try FormatParser.parse(format: "#sequence:global#"),
            [
                .sequence(type: .global())
            ])
        XCTAssertEqual(
            try FormatParser.parse(format: "#sequence:local#"),
            [
                .sequence(type: .local())
            ])
        XCTAssertEqual(
            try FormatParser.parse(format: "#sequence:global:4#"),
            [
                .sequence(type: .global(zeros: 4))
            ])
        XCTAssertEqual(
            try FormatParser.parse(format: "#sequence:local:4#"),
            [
                .sequence(type: .local(zeros: 4))
            ])
        XCTAssertThrowsError(try FormatParser.parse(format: "#sequence:rel#")) { error in
            XCTAssertTrue(
                error is FormatParser.FormatParserError
            )
            if let error = error as? FormatParser.FormatParserError {
                XCTAssertEqual(error, FormatParser.FormatParserError.invalidSequenceType("rel"))
            }
        }
        XCTAssertThrowsError(try FormatParser.parse(format: "#sequence:relative:four#")) { error in
            XCTAssertTrue(
                error is FormatParser.FormatParserError
            )
            if let error = error as? FormatParser.FormatParserError {
                XCTAssertEqual(error, FormatParser.FormatParserError.invalidSequenceFormat("four"))
            }
        }
        XCTAssertThrowsError(try FormatParser.parse(format: "#exif:DateTimeOriginal#/#file:ex#")) {
            error in
            XCTAssertTrue(
                error is FormatParser.FormatParserError
            )
            if let error = error as? FormatParser.FormatParserError {
                XCTAssertEqual(error, FormatParser.FormatParserError.invalidFileProperty("ex"))
            }
        }
    }

    func testFormatExif() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
        let exifMetadata = ["DateTimeOriginal": "2024:01:01 01:02:03"]
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: exifMetadata,
                withFormat: [
                    .exif(property: .property(tag: "DateTimeOriginal", format: "yyMMdd"))
                ]),
            URL(filePath: "200101")
        )
    }

    func testFormatFile() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .file(property: .name)
                ]),
            URL(filePath: "picture.jpg")
        )
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .file(property: .ext)
                ]),
            URL(filePath: "jpg")
        )
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .file(property: .nameNoExt)
                ]),
            URL(filePath: "picture")
        )
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .file(property: .path)
                ]),
            URL(filePath: "folder/subfolder/")
        )
    }

    func testFormatSequence() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .sequence(type: .global())
                ]),
            URL(filePath: "")
        )
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .sequence(type: .global())
                ], absoluteSequenceNumber: 1),
            URL(filePath: "1")
        )
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .sequence(type: .global(zeros: 4))
                ], absoluteSequenceNumber: 42),
            URL(filePath: "0042")
        )
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .sequence(type: .local())
                ]),
            URL(filePath: "")
        )
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .sequence(type: .local())
                ], relativeSequenceNumber: 1),
            URL(filePath: "1")
        )
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: [:],
                withFormat: [
                    .sequence(type: .local(zeros: 4))
                ], relativeSequenceNumber: 42),
            URL(filePath: "0042")
        )
    }

    func testGetFileProperty() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
        XCTAssertEqual(
            FormatParser.get(property: .name, forFile: url),
            "picture.jpg"
        )
        XCTAssertEqual(
            FormatParser.get(property: .ext, forFile: url),
            "jpg"
        )
        XCTAssertEqual(
            FormatParser.get(property: .nameNoExt, forFile: url),
            "picture"
        )
        XCTAssertEqual(
            FormatParser.get(property: .path, forFile: url),
            "folder/subfolder/"
        )
    }

    func testContainsExif() {
        XCTAssertFalse(
            [
                FormatParser.FormatElement.constant(value: ""),
                FormatParser.FormatElement.file(property: .name),
                FormatParser.FormatElement.pathSeparator,
            ].containsExif()
        )
        XCTAssertTrue(
            [
                FormatParser.FormatElement.constant(value: ""),
                FormatParser.FormatElement.file(property: .name),
                FormatParser.FormatElement.pathSeparator,
                FormatParser.FormatElement.exif(property: .property(tag: "DateTimeOriginal")),
            ].containsExif()
        )
    }

    func testExifTags() {
        XCTAssertEqual(
            [
                FormatParser.FormatElement.constant(value: ""),
                FormatParser.FormatElement.file(property: .name),
                FormatParser.FormatElement.pathSeparator,
            ].exifTags(),
            []
        )
        XCTAssertEqual(
            [
                FormatParser.FormatElement.constant(value: ""),
                FormatParser.FormatElement.file(property: .name),
                FormatParser.FormatElement.pathSeparator,
                FormatParser.FormatElement.exif(property: .property(tag: "DateTimeOriginal")),
                FormatParser.FormatElement.pathSeparator,
                FormatParser.FormatElement.exif(property: .property(tag: "ImageSize")),
                FormatParser.FormatElement.pathSeparator,
                FormatParser.FormatElement.exif(property: .property(tag: "DateTimeOriginal")),
            ].exifTags(),
            ["DateTimeOriginal", "ImageSize"]
        )
    }

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
    }

    func testSequenceDescription() {
        // File with extension
        XCTAssertEqual(
            [
                FormatParser.FormatElement.file(property: .name),
                FormatParser.FormatElement.pathSeparator,
                FormatParser.FormatElement.exif(
                    property: .property(tag: "DateTimeOriginal", format: "yyyyMM")),
                FormatParser.FormatElement.pathSeparator,
                FormatParser.FormatElement.sequence(type: .local(zeros: 3)),
                FormatParser.FormatElement.constant(value: "_"),
                FormatParser.FormatElement.sequence(type: .global(zeros: 5)),
                FormatParser.FormatElement.constant(value: "."),
                FormatParser.FormatElement.file(property: .ext),
            ].asString,
            "#file:name#/#exif:DateTimeOriginal:yyyyMM#/#sequence:local:3#_#sequence:global:5#.#file:ext#"
        )
    }
}
