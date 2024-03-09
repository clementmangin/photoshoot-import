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

    func testParseFileVariableName() {
        XCTAssertNoThrow(try FormatParser.FileProperty.fromString(string: "name"))
        XCTAssertEqual(
            try FormatParser.FileProperty.fromString(string: "name"),
            FormatParser.FileProperty.name
        )
    }

    func testParseFileVariableNameNoExt() {
        XCTAssertNoThrow(try FormatParser.FileProperty.fromString(string: "namenoext"))
        XCTAssertEqual(
            try FormatParser.FileProperty.fromString(string: "namenoext"),
            FormatParser.FileProperty.nameNoExt
        )
    }

    func testParseFileVariableExt() {
        XCTAssertNoThrow(try FormatParser.FileProperty.fromString(string: "ext"))
        XCTAssertEqual(
            try FormatParser.FileProperty.fromString(string: "ext"),
            FormatParser.FileProperty.ext
        )
    }

    func testParseFileVariablePath() {
        XCTAssertNoThrow(try FormatParser.FileProperty.fromString(string: "path"))
        XCTAssertEqual(
            try FormatParser.FileProperty.fromString(string: "path"),
            FormatParser.FileProperty.path
        )
    }

    func testParseFileVariableCreationDate() {
        XCTAssertNoThrow(try FormatParser.FileProperty.fromString(string: "creationdate"))
        XCTAssertEqual(
            try FormatParser.FileProperty.fromString(string: "creationdate"),
            FormatParser.FileProperty.creationDate()
        )
        XCTAssertNoThrow(try FormatParser.FileProperty.fromString(string: "creationdate:yyyyMM"))
        XCTAssertEqual(
            try FormatParser.FileProperty.fromString(string: "creationdate:yyyyMM"),
            FormatParser.FileProperty.creationDate(format: "yyyyMM")
        )
    }

    func testParseFileVariableModificationDate() {
        XCTAssertNoThrow(try FormatParser.FileProperty.fromString(string: "modificationdate"))
        XCTAssertEqual(
            try FormatParser.FileProperty.fromString(string: "modificationdate"),
            FormatParser.FileProperty.modificationDate()
        )
        XCTAssertNoThrow(try FormatParser.FileProperty.fromString(string: "modificationdate:HHmm"))
        XCTAssertEqual(
            try FormatParser.FileProperty.fromString(string: "modificationdate:HHmm"),
            FormatParser.FileProperty.modificationDate(format: "HHmm")
        )
    }

    func testParseExifVariable() {
        XCTAssertEqual(
            FormatParser.ExifProperty.fromString(string: "ImageSize"),
            FormatParser.ExifProperty.property(tag: "ImageSize")
        )
    }

    func testParseExifVariableFormatted() {
        XCTAssertEqual(
            FormatParser.ExifProperty.fromString(string: "DateTimeOriginal:yyyy/MM"),
            FormatParser.ExifProperty.property(tag: "DateTimeOriginal", format: "yyyy/MM")
        )
    }

    func testParseSequenceGlobal() {
        XCTAssertNoThrow(try FormatParser.SequenceType.fromString(string: "global"))
        XCTAssertEqual(
            try FormatParser.SequenceType.fromString(string: "global"),
            FormatParser.SequenceType.global()
        )
        XCTAssertNoThrow(try FormatParser.SequenceType.fromString(string: "global:4"))
        XCTAssertEqual(
            try FormatParser.SequenceType.fromString(string: "global:4"),
            FormatParser.SequenceType.global(zeros: 4)
        )
        XCTAssertThrowsError(try FormatParser.SequenceType.fromString(string: "global:err")) {
            error in
            guard case FormatParser.FormatParserError.invalidSequenceFormat(let value) = error
            else {
                return XCTFail("Unexpected error thrown")
            }
            XCTAssertEqual(value, "err")
        }
    }

    func testParseSequenceLocal() {
        XCTAssertNoThrow(try FormatParser.SequenceType.fromString(string: "local"))
        XCTAssertEqual(
            try FormatParser.SequenceType.fromString(string: "local"),
            FormatParser.SequenceType.local()
        )
        XCTAssertNoThrow(try FormatParser.SequenceType.fromString(string: "local:4"))
        XCTAssertEqual(
            try FormatParser.SequenceType.fromString(string: "local:4"),
            FormatParser.SequenceType.local(zeros: 4)
        )
        XCTAssertThrowsError(try FormatParser.SequenceType.fromString(string: "local:err")) {
            error in
            guard case FormatParser.FormatParserError.invalidSequenceFormat(let value) = error
            else {
                return XCTFail("Unexpected error thrown")
            }
            XCTAssertEqual(value, "err")
        }
    }

    func testParseFormat() throws {
        XCTAssertEqual(
            try FormatParser.parse(
                format:
                    "#invalid#/#exif:DateTimeOriginal:yyyyMM#/photo #sequence:local:4#.#file:ext#"),
            [
                .constant(value: "#invalid#"),
                .pathSeparator,
                .exif(property: .property(tag: "DateTimeOriginal", format: "yyyyMM")),
                .pathSeparator,
                .constant(value: "photo "),
                .sequence(type: .local(zeros: 4)),
                .constant(value: "."),
                .file(property: .ext),
            ])
    }

    func testFormatExif() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
        let exifMetadata = ["ImageSize": "1024x768"]
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: exifMetadata,
                withFormat: [
                    .exif(property: .property(tag: "ImageSize"))
                ]),
            URL(filePath: "1024x768")
        )
    }

    func testFormatExifFormatted() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
        let exifMetadata = ["DateTimeOriginal": "2024:01:01 01:02:03", "ImageSize": "1024x768"]
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: exifMetadata,
                withFormat: [
                    .exif(property: .property(tag: "ImageSize")),
                    .exif(property: .property(tag: "CreateDate")),
                    .exif(property: .property(tag: "DateTimeOriginal", format: "yy/MM")),
                ]),
            URL(filePath: "1024x76824/01")
        )
    }

    func testFormatExifFormattedInvalidFormat() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
        let exifMetadata = ["ImageSize": "1024x768"]
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: exifMetadata,
                withFormat: [
                    .exif(property: .property(tag: "ImageSize", format: "yy/MM"))
                ]),
            URL(filePath: "1024x768")
        )
    }

    func testFormatExifMissing() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
        let exifMetadata = ["DateTimeOriginal": "2024:01:01 01:02:03"]
        XCTAssertEqual(
            FormatParser.format(
                file: url, exifMetadata: exifMetadata,
                withFormat: [
                    .exif(property: .property(tag: "CreateDate"))
                ]),
            URL(filePath: "")
        )
    }

    func testFormatFileName() throws {
        XCTAssertEqual(
            FormatParser.format(
                file: URL(filePath: "folder/subfolder/picture.jpg"), exifMetadata: [:],
                withFormat: [
                    .file(property: .name)
                ]),
            URL(filePath: "picture.jpg")
        )
    }

    func testFormatFileExt() throws {
        XCTAssertEqual(
            FormatParser.format(
                file: URL(filePath: "folder/subfolder/picture.jpg"), exifMetadata: [:],
                withFormat: [
                    .file(property: .ext)
                ]),
            URL(filePath: "jpg")
        )
    }

    func testFormatFileNameNoExt() throws {
        XCTAssertEqual(
            FormatParser.format(
                file: URL(filePath: "folder/subfolder/picture.jpg"), exifMetadata: [:],
                withFormat: [
                    .file(property: .nameNoExt)
                ]),
            URL(filePath: "picture")
        )
    }

    func testFormatFilePath() throws {
        XCTAssertEqual(
            FormatParser.format(
                file: URL(filePath: "folder/subfolder/picture.jpg"), exifMetadata: [:],
                withFormat: [
                    .file(property: .path)
                ]),
            URL(filePath: "folder/subfolder/")
        )
    }

    func testFormatSequenceGlobal() throws {
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
    }

    func testFormatSequenceLocal() throws {
        let url = URL(filePath: "folder/subfolder/picture.jpg")
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
        //        TODO: find a solution to test these file properties
        //        url.setTemporaryResourceValue(
        //            "2024-01-01 13:12:11".asDate(withFormat: "yyyy-MM-dd HH:mm:ss"),
        //            forKey: .creationDateKey)
        //        XCTAssertEqual(
        //            FormatParser.get(property: .modificationDate(), forFile: url),
        //            "20240203")
        //        url.setTemporaryResourceValue(
        //            "2024-02-10 01:02:03".asDate(withFormat: "yyyy-MM-dd HH:mm:ss"),
        //            forKey: .contentModificationDateKey)
        //        XCTAssertEqual(
        //            FormatParser.get(property: .creationDate(), forFile: url),
        //            "20240203"
        //        )
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
            Set(["DateTimeOriginal", "ImageSize"])
        )
    }

    func testFileNameDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.FileProperty.name),
            "name"
        )
    }

    func testFileExtDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.FileProperty.ext),
            "ext"
        )
    }

    func testFileNameNoExtDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.FileProperty.nameNoExt),
            "namenoext"
        )
    }

    func testFilePathDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.FileProperty.path),
            "path"
        )
    }

    func testFileCreationDateDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.FileProperty.creationDate(format: "yyyyMMdd")),
            "creationdate:yyyyMMdd"
        )
        XCTAssertEqual(
            String(describing: FormatParser.FileProperty.creationDate()),
            "creationdate"
        )
    }

    func testFileModificationDateDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.FileProperty.modificationDate()),
            "modificationdate"
        )
        XCTAssertEqual(
            String(describing: FormatParser.FileProperty.modificationDate(format: "yyyyMMdd")),
            "modificationdate:yyyyMMdd"
        )
    }

    func testExifDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.ExifProperty.property(tag: "ImageSize")),
            "ImageSize"
        )
        XCTAssertEqual(
            String(
                describing: FormatParser.ExifProperty.property(
                    tag: "DateTimeOriginal", format: "yyyyMMdd")),
            "DateTimeOriginal:yyyyMMdd"
        )
    }

    func testSequenceGlobalDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.SequenceType.global()),
            "global"
        )
        XCTAssertEqual(
            String(describing: FormatParser.SequenceType.global(zeros: 4)),
            "global:4"
        )
    }

    func testSequenceDescription() {
        XCTAssertEqual(
            String(describing: FormatParser.SequenceType.local()),
            "local"
        )
        XCTAssertEqual(
            String(describing: FormatParser.SequenceType.local(zeros: 4)),
            "local:4"
        )
    }

    func testFormatDescription() {
        XCTAssertEqual(
            [
                FormatParser.FormatElement.file(property: .name),
                FormatParser.FormatElement.pathSeparator,
                FormatParser.FormatElement.exif(
                    property: .property(tag: "DateTimeOriginal", format: "yyyyMM")),
                FormatParser.FormatElement.pathSeparator,
                FormatParser.FormatElement.sequence(type: .local()),
                FormatParser.FormatElement.constant(value: "_"),
                FormatParser.FormatElement.sequence(type: .global(zeros: 5)),
                FormatParser.FormatElement.constant(value: "."),
                FormatParser.FormatElement.file(property: .ext),
            ].asString,
            "#file:name#/#exif:DateTimeOriginal:yyyyMM#/#sequence:local#_#sequence:global:5#.#file:ext#"
        )
    }
}
