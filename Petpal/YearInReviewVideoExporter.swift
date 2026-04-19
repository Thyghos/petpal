// Builds a 1080×1920 H.264 MP4 slideshow from slide images (30 fps, 3s per slide, straight cuts).

import Foundation
import AVFoundation
import UIKit
import CoreVideo
import CoreImage

enum YearInReviewVideoExporter {
    private static let logPrefix = "[YIRVideoExporter]"

    private static func log(_ message: String) {
        print("\(logPrefix) \(message)")
    }

    private static let fps: Int32 = 30
    private static let holdSeconds: Double = 3

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// - Parameter limitedSlideCount: If non-nil, only the first N slides are encoded (e.g. `2` to validate the pipeline).
    static func exportVideo(slideImages: [UIImage], limitedSlideCount: Int? = nil) async throws -> URL {
        var images = slideImages
        if let limit = limitedSlideCount, limit > 0 {
            images = Array(slideImages.prefix(limit))
        }
        guard !images.isEmpty else {
            log("error: no slides after trim")
            throw NSError(
                domain: "YearInReviewVideoExporter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No slides"]
            )
        }

        log("begin export slideCount=\(images.count) limitedSlideCount=\(limitedSlideCount.map(String.init) ?? "nil")")

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetpalYIR-\(UUID().uuidString).mp4", isDirectory: false)

        if FileManager.default.fileExists(atPath: outURL.path) {
            do {
                try FileManager.default.removeItem(at: outURL)
                log("deleted existing file at path=\(outURL.path)")
            } catch {
                log("failed to delete existing file: \(error.localizedDescription)")
                throw error
            }
        }

        log("output URL path=\(outURL.path) extension=\(outURL.pathExtension)")

        return try await Task.detached(priority: .userInitiated) {
            try await writeVideo(images: images, outputURL: outURL)
            return outURL
        }.value
    }

    private static func writeVideo(images: [UIImage], outputURL: URL) async throws {
        let width = 1080
        let height = 1920
        let holdFrames = Int(Double(fps) * holdSeconds)
        log("holdFrames=\(holdFrames) (fps=\(fps) holdSeconds=\(holdSeconds))")

        var timeline: [UIImage] = []
        for img in images {
            for _ in 0..<holdFrames {
                timeline.append(img)
            }
        }
        log("timeline frame count=\(timeline.count)")

        log("creating AVAssetWriter url=\(outputURL.path)")
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            log("AVAssetWriter init failed: \(error.localizedDescription)")
            throw error
        }
        log("AVAssetWriter created status=\(writer.status.rawValue)")

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ] as [String: Any]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        log("AVAssetWriterInput expectsMediaDataInRealTime=true")

        let sourceAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttrs
        )

        guard writer.canAdd(input) else {
            log("error: writer.canAdd(input) == false")
            throw NSError(domain: "YearInReviewVideoExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
        }
        writer.add(input)
        log("video input added")

        guard writer.startWriting() else {
            let err = writer.error?.localizedDescription ?? "unknown"
            log("startWriting failed: \(err)")
            throw writer.error ?? NSError(domain: "YearInReviewVideoExporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "startWriting failed"])
        }
        log("startWriting succeeded")

        writer.startSession(atSourceTime: .zero)
        log("startSession(atSourceTime: .zero)")

        var poolWait = 0
        while adaptor.pixelBufferPool == nil && poolWait < 100 {
            try await Task.sleep(nanoseconds: 10_000_000)
            poolWait += 1
        }
        if let pool = adaptor.pixelBufferPool {
            log("pixel buffer pool ready (waits=\(poolWait)) pool=\(pool)")
        } else {
            log("warning: pixelBufferPool still nil after \(poolWait) waits — will use CVPixelBufferCreate fallback")
        }

        let frameDuration = CMTime(value: 1, timescale: fps)
        var frameIndex: Int64 = 0

        for (idx, image) in timeline.enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            guard let buffer = pixelBuffer(
                from: image,
                width: width,
                height: height,
                adaptor: adaptor
            ) else {
                log("error: failed to create pixel buffer for timeline index=\(idx) frameIndex=\(frameIndex)")
                throw NSError(
                    domain: "YearInReviewVideoExporter",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"]
                )
            }

            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            let ok = adaptor.append(buffer, withPresentationTime: presentationTime)
            if !ok {
                let err = writer.error?.localizedDescription ?? "append returned false"
                log("error: append failed at frameIndex=\(frameIndex) timelineIndex=\(idx): \(err)")
                throw writer.error ?? NSError(domain: "YearInReviewVideoExporter", code: 6, userInfo: [NSLocalizedDescriptionKey: err])
            }
            log("appended frame frameIndex=\(frameIndex) timelineIndex=\(idx)/\(timeline.count - 1) pts=\(CMTimeGetSeconds(presentationTime))s")
            frameIndex += 1
        }

        log("finished appending \(frameIndex) frames, marking input finished")
        input.markAsFinished()

        log("calling finishWriting…")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }

        log("finishWriting returned status=\(writer.status.rawValue) AVAssetWriter.error=\(writer.error?.localizedDescription ?? "nil")")

        if writer.status != .completed {
            let err = writer.error
            throw err ?? NSError(
                domain: "YearInReviewVideoExporter",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Export finished with status \(writer.status.rawValue)"]
            )
        }

        log("writing finished successfully path=\(outputURL.path) fileExists=\(FileManager.default.fileExists(atPath: outputURL.path))")
    }

    /// Prefer the adaptor’s pixel buffer pool; fall back to standalone allocation.
    private static func pixelBuffer(
        from image: UIImage,
        width: Int,
        height: Int,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) -> CVPixelBuffer? {
        if let pool = adaptor.pixelBufferPool {
            var out: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &out)
            if status == kCVReturnSuccess, let pb = out {
                renderCIImage(from: image, into: pb, width: width, height: height)
                return pb
            }
            log("warning: pool create failed status=\(status), falling back to CVPixelBufferCreate")
        }

        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let createStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard createStatus == kCVReturnSuccess, let pb = buffer else {
            log("error: CVPixelBufferCreate failed status=\(createStatus)")
            return nil
        }
        renderCIImage(from: image, into: pb, width: width, height: height)
        return pb
    }

    private static func renderCIImage(from image: UIImage, into buffer: CVPixelBuffer, width: Int, height: Int) {
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        let scaled: CIImage = {
            guard let ci = CIImage(image: image) else {
                return CIImage(color: CIColor.white).cropped(to: extent)
            }
            let scaleX = CGFloat(width) / max(ci.extent.width, 1)
            let scaleY = CGFloat(height) / max(ci.extent.height, 1)
            let s = min(scaleX, scaleY)
            return ci.transformed(by: CGAffineTransform(scaleX: s, y: s))
                .cropped(to: extent)
        }()
        ciContext.render(scaled, to: buffer, bounds: extent, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
}
