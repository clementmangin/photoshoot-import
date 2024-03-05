//
//  FormatParser.swift
//  Photoshoot Import
//
//  Created by Clément Mangin on 2024-03-01.
//

import Foundation

struct FormatParser {

    enum FormatParserError: Error, Equatable {
        case invalidFileProperty(String)
        case invalidSequenceType(String)
        case invalidSequenceFormat(String)
    }

    enum ExifProperty: Equatable, Hashable, CustomStringConvertible {
        case property(tag: String, format: String? = nil)

        var description: String {
            switch self {
            case .property(let tag, let format):
                if let format = format {
                    return "\(tag):\(format)"
                } else {
                    return tag
                }
            }
        }

        static func fromString(string: String) -> Self {
            let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
            return .property(tag: parts[0], format: parts.count > 1 ? parts[1] : nil)
        }
    }

    enum FileProperty: Equatable, Hashable, CustomStringConvertible {
        case name
        case nameNoExt
        case ext
        case path
        case creationDate(format: String? = nil)
        case modificationDate(format: String? = nil)

        var description: String {
            switch self {
            case .name:
                return "name"
            case .nameNoExt:
                return "namenoext"
            case .ext:
                return "ext"
            case .path:
                return "path"
            case .creationDate(let format):
                if let format = format {
                    return "creationdate:\(format)"
                } else {
                    return "creationdate"
                }
            case .modificationDate(let format):
                if let format = format {
                    return "modificationdate:\(format)"
                } else {
                    return "modificationdate"
                }
            }
        }

        static func fromString(string: String) throws -> Self {
            let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
            let fileProperty: Self
            switch parts[0] {
            case "name":
                fileProperty = .name
            case "namenoext":
                fileProperty = .nameNoExt
            case "ext":
                fileProperty = .ext
            case "path":
                return .path
            case "creationdate":
                if parts.count > 1 {
                    return .creationDate(format: parts[1])
                } else {
                    return .creationDate()
                }
            case "modificationdate":
                if parts.count > 1 {
                    return .modificationDate(format: parts[1])
                } else {
                    return .modificationDate()
                }
            default:
                throw FormatParserError.invalidFileProperty(string)
            }
            return fileProperty
        }
    }

    enum SequenceType: Equatable, Hashable, CustomStringConvertible {
        case global(zeros: Int? = nil)
        case local(zeros: Int? = nil)

        var description: String {
            switch self {
            case .global(let zeros):
                if let zeros = zeros {
                    return "global:\(zeros)"
                } else {
                    return "global"
                }
            case .local(let zeros):
                if let zeros = zeros {
                    return "local:\(zeros)"
                } else {
                    return "local"
                }
            }
        }

        static func fromString(string: String) throws -> Self {
            let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
            let zeros: Int?
            let sequenceType: Self
            if parts.count > 1 {
                guard let z = Int(parts[1]) else {
                    throw FormatParserError.invalidSequenceFormat(parts[1])
                }
                zeros = z
            } else {
                zeros = nil
            }
            switch parts[0] {
            case "global":
                sequenceType = .global(zeros: zeros)
            case "local":
                sequenceType = .local(zeros: zeros)
            default:
                throw FormatParserError.invalidSequenceType(string)
            }
            return sequenceType
        }
    }

    enum FormatElement: Equatable, Hashable, Identifiable, CustomStringConvertible {
        case constant(value: String)
        case pathSeparator
        case exif(property: ExifProperty)
        case file(property: FileProperty)
        case sequence(type: SequenceType)

        var id: Self {
            return self
        }

        var description: String {
            switch self {
            case .constant(let value):
                return value
            case .exif(let field):
                return "#exif:\(field)#"
            case .file(let property):
                return "#file:\(property)#"
            case .sequence(let type):
                return "#sequence:\(String(describing: type))#"
            case .pathSeparator:
                return "/"
            }
        }
    }

    private static let regex = /#(?<category>file|exif|sequence):(?<config>[^#]+)#/

    public static func splitFolders(forPath path: String) -> [FormatElement] {
        return path.split(separator: "/", omittingEmptySubsequences: false).map {
            [FormatElement.constant(value: String($0))]
        }.joined(separator: [FormatElement.pathSeparator]).compactMap { $0 }
    }

    private static func categoryToElement(_ category: String, _ configuration: String) throws
        -> FormatElement
    {
        switch category {
        case "file":
            let property = try FileProperty.fromString(string: configuration)
            return .file(property: property)
        case "exif":
            let property = ExifProperty.fromString(string: configuration)
            return .exif(property: property)
        case "sequence":
            let sequenceType = try SequenceType.fromString(string: configuration)
            return .sequence(type: sequenceType)
        default:
            return .constant(value: "#\(category):\(configuration)#")
        }
    }

    public static func parse(format: String) throws -> [FormatElement] {
        let constants: [[FormatElement]] = format.split(
            separator: regex, omittingEmptySubsequences: false
        ).map(String.init).map(FormatParser.splitFolders)
        let variables: [FormatElement] = try format.matches(of: regex).map {
            try categoryToElement(String($0.output.category), String($0.output.config))
        }
        var result: [FormatElement] = []
        for i in 0..<constants.count {
            result.append(contentsOf: constants[i].filter { $0 != .constant(value: "") })
            if i < variables.count {
                result.append(variables[i])
            }
        }
        return result
    }

    public static func format(
        file: URL, exifMetadata exif: [String: String], withFormat format: [FormatElement],
        absoluteSequenceNumber: Int? = nil, relativeSequenceNumber: Int? = nil,
        relativeTo: URL? = nil
    ) -> URL {
        return URL(
            filePath: format.map {
                switch $0 {
                case .constant(let value):
                    return value
                case .exif(.property(let tag, let format)):
                    if let value = exif[tag] {
                        if let format = format,
                            let date = value.asDate(withFormat: "yyyy:MM:dd HH:mm:ss"),
                            let d = date.asString(withFormat: format)
                        {
                            return d
                        } else {
                            return value
                        }
                    } else {
                        return ""
                    }
                case .file(let property):
                    return FormatParser.get(property: property, forFile: file)
                case .pathSeparator:
                    return "/"
                case .sequence(let type):
                    switch type {
                    case .global(let format):
                        guard let absoluteSequenceNumber = absoluteSequenceNumber else {
                            return ""
                        }
                        let format = format ?? 1
                        return String(format: "%0\(format)d", absoluteSequenceNumber)
                    case .local(let format):
                        guard let relativeSequenceNumber = relativeSequenceNumber else {
                            return ""
                        }
                        let format = format ?? 1
                        return String(format: "%0\(format)d", relativeSequenceNumber)
                    }
                }
            }.joined(), relativeTo: relativeTo)
    }

    public static func get(property: FileProperty, forFile file: URL) -> String {
        switch property {
        case .ext:
            return file.pathExtension
        case .name:
            return file.lastPathComponent
        case .nameNoExt:
            return file.deletingPathExtension().lastPathComponent
        case .path:
            return file.deletingLastPathComponent().relativeString
        case .creationDate(let format):
            do {
                let attr = try file.resourceValues(forKeys: [.creationDateKey])
                let format = format ?? "yyyyMMdd"
                if let date = attr.creationDate, let result = date.asString(withFormat: format) {
                    return result
                }
                return ""
            } catch {
                return ""
            }
        case .modificationDate(let format):
            do {
                let attr = try file.resourceValues(forKeys: [.contentModificationDateKey])
                let format = format ?? "yyyyMMdd"
                if let date = attr.contentModificationDate,
                    let result = date.asString(withFormat: format)
                {
                    return result
                }
                return ""
            } catch {
                return ""
            }
        }
    }

    public static func prepareImport(
        srcFiles: [URL], inSrcFolder srcFolder: URL, toDestFolder destFolder: URL,
        withFormat format: [FormatElement],
        exifMethod: (_ path: URL, _ tags: [String]) throws -> [String: String]
    ) throws -> [(src: URL, dest: URL)] {
        let exifTags = format.exifTags()

        var fileRanks: [URL: Int] = [:]
        var filePairs: [(src: URL, dest: URL)] = []

        let formatContainsRelativeSequence = format.contains {
            switch $0 {
            case .sequence(type: .local(_)):
                return true
            default:
                return false
            }
        }

        for (index, srcFile) in srcFiles.sorted(by: { $0.absoluteString < $1.absoluteString })
            .enumerated()
        {
            let exifMetadata = exifTags.isEmpty ? [:] : try exifMethod(srcFile, Array(exifTags))
            let destFile = FormatParser.format(
                file: srcFile, exifMetadata: exifMetadata, withFormat: format,
                absoluteSequenceNumber: index + 1, relativeTo: destFolder)

            if formatContainsRelativeSequence {
                let rank = fileRanks[destFile.deletingLastPathComponent(), default: 0] + 1
                fileRanks[destFile.deletingLastPathComponent()] = rank
                let sequencedDestFile = FormatParser.format(
                    file: srcFile, exifMetadata: exifMetadata, withFormat: format,
                    absoluteSequenceNumber: index + 1, relativeSequenceNumber: rank,
                    relativeTo: destFolder
                )
                filePairs.append((src: srcFile, dest: sequencedDestFile))
            } else {
                filePairs.append((src: srcFile, dest: destFile))
            }
        }

        return filePairs
    }
}

extension Sequence where Element == FormatParser.FormatElement {
    func containsExif() -> Bool {
        return self.contains {
            switch $0 {
            case .exif:
                return true
            default:
                return false
            }
        }
    }

    func exifTags() -> Set<String> {
        return Set<String>(
            self.reduce(into: [String]()) {
                switch $1 {
                case .exif(.property(let tag, _)):
                    $0.append(tag)
                default: break
                }
            })
    }

    var asString: String {
        return self.map { String(describing: $0) }.joined()
    }
}
