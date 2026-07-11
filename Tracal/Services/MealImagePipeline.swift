import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct MealImageSanitizer: Sendable {
    public var maximumPixelDimension: Int
    public var jpegQuality: Double

    public init(maximumPixelDimension: Int = 2_048, jpegQuality: Double = 0.82) {
        self.maximumPixelDimension = max(512, maximumPixelDimension)
        self.jpegQuality = min(1, max(0.5, jpegQuality))
    }

    /// Downsamples, applies EXIF orientation, and re-encodes only pixels into a
    /// new JPEG. No source metadata dictionary is copied to the destination.
    public func sanitize(_ sourceData: Data) throws -> SanitizedMealImage {
        guard
            !sourceData.isEmpty,
            let source = CGImageSourceCreateWithData(sourceData as CFData, nil)
        else {
            throw MealAnalysisError.unreadableImage
        }

        let thumbnailOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw MealAnalysisError.unreadableImage
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw MealAnalysisError.unreadableImage
        }

        let destinationOptions: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, destinationOptions)

        guard CGImageDestinationFinalize(destination) else {
            throw MealAnalysisError.unreadableImage
        }

        return SanitizedMealImage(
            data: output as Data,
            pixelWidth: image.width,
            pixelHeight: image.height
        )
    }
}

/// Stores only sanitized images. Files are protected whenever the device is
/// locked and are kept outside SwiftData so database snapshots contain no image
/// bytes or metadata.
public actor ProtectedMealImageStore {
    private let fileManager: FileManager
    private let baseDirectoryURL: URL
    private let directoryURL: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        baseDirectoryURL = documents
        directoryURL = documents
            .appendingPathComponent("ProtectedMealDrafts", isDirectory: true)
    }

    @discardableResult
    public func save(_ image: SanitizedMealImage, id: UUID = UUID()) throws -> URL {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            let url = directoryURL.appendingPathComponent("\(id.uuidString).jpg")
            try image.data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            throw MealAnalysisError.imageStorageFailed
        }
    }

    public func relativePath(for url: URL) -> String {
        let basePath = baseDirectoryURL.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(basePath) else { return url.lastPathComponent }
        return String(path.dropFirst(basePath.count))
    }

    public func remove(path: String?) {
        guard let path, !path.isEmpty else { return }
        let url = path.hasPrefix("/")
            ? URL(fileURLWithPath: path).standardizedFileURL
            : baseDirectoryURL.appendingPathComponent(path).standardizedFileURL
        let protectedDirectory = directoryURL.standardizedFileURL.path
        guard url.path.hasPrefix(protectedDirectory + "/") else { return }
        try? fileManager.removeItem(at: url)
    }

    public func data(path: String?) -> Data? {
        guard let url = resolvedURL(path: path) else { return nil }
        return try? Data(contentsOf: url, options: [.mappedIfSafe])
    }

    public func restore(_ data: Data, id: UUID) throws -> String {
        guard !data.isEmpty else { throw MealAnalysisError.imageStorageFailed }
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            let url = directoryURL.appendingPathComponent("\(id.uuidString).jpg")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return relativePath(for: url)
        } catch {
            throw MealAnalysisError.imageStorageFailed
        }
    }

    public func removeAll() {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try? fileManager.removeItem(at: directoryURL)
    }


    private func resolvedURL(path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let url = path.hasPrefix("/")
            ? URL(fileURLWithPath: path).standardizedFileURL
            : baseDirectoryURL.appendingPathComponent(path).standardizedFileURL
        let protectedDirectory = directoryURL.standardizedFileURL.path
        guard url.path.hasPrefix(protectedDirectory + "/") else { return nil }
        return url
    }
}
