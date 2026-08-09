#!/usr/bin/env swift

import AVFoundation
import CoreVideo
import Foundation

let arguments = CommandLine.arguments
guard (2...3).contains(arguments.count) else {
    fputs("usage: generate_playback_fixture.swift OUTPUT.mp4 [DURATION_SECONDS]\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
try? FileManager.default.removeItem(at: outputURL)

let width = 640
let height = 360
let frameRate: Int32 = 30
let durationSeconds = arguments.count == 3 ? (Int(arguments[2]) ?? 12) : 12
guard durationSeconds > 0 else {
    fputs("duration must be greater than zero\n", stderr)
    exit(2)
}
let frameCount = Int(frameRate) * durationSeconds
let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let input = AVAssetWriterInput(
    mediaType: .video,
    outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
            AVVideoAverageBitRateKey: 1_200_000,
            AVVideoMaxKeyFrameIntervalKey: Int(frameRate)
        ]
    ]
)
input.expectsMediaDataInRealTime = false

let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height
    ]
)
guard writer.canAdd(input) else {
    throw NSError(domain: "NastartPlaybackFixture", code: 1)
}
writer.add(input)
guard writer.startWriting() else {
    throw writer.error ?? NSError(domain: "NastartPlaybackFixture", code: 2)
}
writer.startSession(atSourceTime: .zero)

let queue = DispatchQueue(label: "com.nastart.playback-fixture")
let completion = DispatchSemaphore(value: 0)
var frameIndex = 0

input.requestMediaDataWhenReady(on: queue) {
    while input.isReadyForMoreMediaData {
        guard frameIndex < frameCount else {
            input.markAsFinished()
            writer.finishWriting {
                completion.signal()
            }
            return
        }
        guard let pool = adaptor.pixelBufferPool else {
            writer.cancelWriting()
            completion.signal()
            return
        }
        var optionalBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer) == kCVReturnSuccess,
              let pixelBuffer = optionalBuffer else {
            writer.cancelWriting()
            completion.signal()
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
            let movingBar = (frameIndex * 5) % width
            for y in 0..<height {
                let row = pixels.advanced(by: y * rowBytes)
                for x in 0..<width {
                    let offset = x * 4
                    let isBar = abs(x - movingBar) < 14
                    row[offset] = isBar ? 245 : UInt8((x * 180 / width) + 24)
                    row[offset + 1] = isBar ? 245 : UInt8((y * 150 / height) + 42)
                    row[offset + 2] = isBar ? 245 : UInt8(190 - (x * 110 / width))
                    row[offset + 3] = 255
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let time = CMTime(value: CMTimeValue(frameIndex), timescale: frameRate)
        guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
            writer.cancelWriting()
            completion.signal()
            return
        }
        frameIndex += 1
    }
}

completion.wait()
guard writer.status == .completed else {
    throw writer.error ?? NSError(domain: "NastartPlaybackFixture", code: 3)
}
print(outputURL.path)
