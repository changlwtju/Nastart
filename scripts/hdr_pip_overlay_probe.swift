// Mac-only offline experiment. Does not import or modify the App compositor.
// Run with a matching Xcode Swift/SDK and one private output directory argument.
import Foundation
import CoreGraphics
import CoreImage
import CoreVideo
import CoreMedia
import CoreText
import ImageIO

guard (2...3).contains(CommandLine.arguments.count) else {
    fatalError("Usage: swift hdr_pip_overlay_probe.swift PRIVATE_OUTPUT_DIRECTORY [DECODED_BITMAP_PNG]")
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let linear = CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020)!
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CIContext(options: [.workingColorSpace: linear, .workingFormat: CIFormat.RGBAh,
                                 .cacheIntermediates: false])

func stamp(_ buffer: CVPixelBuffer, transfer: CFString) {
    CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey,
                          kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
    CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, transfer, .shouldPropagate)
    CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey,
                          kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
}
func makeBuffer(width: Int, height: Int, format: OSType) -> CVPixelBuffer {
    var result: CVPixelBuffer?
    precondition(CVPixelBufferCreate(nil, width, height, format,
        [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &result) == 0)
    return result!
}
func sample(_ image: CIImage, x: Int, y: Int) -> [Float] {
    var values = [Float](repeating: 0, count: 4)
    values.withUnsafeMutableBytes { bytes in
        context.render(image, toBitmap: bytes.baseAddress!, rowBytes: 16,
                       bounds: CGRect(x: x, y: y, width: 1, height: 1),
                       format: .RGBAf, colorSpace: linear)
    }
    return values
}
func savePNG(_ image: CGImage, name: String) {
    let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent(name) as CFURL,
                                                     "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
}
func pqNits(_ encoded: Double) -> Double {
    let m1 = 2610.0 / 16384, m2 = 2523.0 / 32
    let c1 = 3424.0 / 4096, c2 = 2413.0 / 128, c3 = 2392.0 / 128
    let power = pow(encoded, 1 / m2)
    return 10000 * pow(max(power - c1, 0) / (c2 - c3 * power), 1 / m1)
}
func yCode(_ buffer: CVPixelBuffer, x: Int, y: Int) -> Int {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let row = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0) / 2
    return Int(CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!
        .assumingMemoryBound(to: UInt16.self)[y * row + x] >> 6)
}

// Rasterized Chinese/Latin glyphs plus opaque, half-alpha and colored controls.
// This is a generated bitmap shaped like a decoded PGS object, not a PGS decoder test.
let bitmapWidth = 512, bitmapHeight = 128
let cg = CGContext(data: nil, width: bitmapWidth, height: bitmapHeight, bitsPerComponent: 8,
                   bytesPerRow: bitmapWidth * 4, space: srgb,
                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let font = CTFontCreateWithName("PingFangSC-Medium" as CFString, 32, nil)
let caption = "字幕 HDR PiP gy — 测试"
var characters = Array(caption.utf16)
var glyphs = [CGGlyph](repeating: 0, count: characters.count)
let allGlyphsAvailable = CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
precondition(allGlyphsAvailable)
let line = CTLineCreateWithAttributedString(NSAttributedString(string: caption, attributes: [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
]))
cg.textPosition = CGPoint(x: 8, y: 66)
CTLineDraw(line, cg)
for (x, color) in [(8, CGColor(gray: 1, alpha: 1)),
                   (56, CGColor(gray: 1, alpha: 0.5)),
                   (104, CGColor(red: 1, green: 0, blue: 0, alpha: 1))] {
    cg.setFillColor(color)
    cg.fill(CGRect(x: x, y: 8, width: 32, height: 32))
}
let bitmap: CGImage
if CommandLine.arguments.count == 3 {
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL, nil)!
    bitmap = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    precondition(bitmap.width == bitmapWidth && bitmap.height == bitmapHeight)
} else {
    bitmap = cg.makeImage()!
}
savePNG(bitmap, name: "generated-caption.png")
let bitmapImage = CIImage(cgImage: bitmap, options: [.colorSpace: srgb])
let bitmapHalfAlpha = sample(bitmapImage, x: 72, y: 24)[3]
let bitmapHalfOverBlack = sample(bitmapImage.composited(over:
    CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1, colorSpace: linear)!)), x: 72, y: 24)

var rows: [[String: Any]] = []
for (name, space, transfer) in [("PQ", CGColorSpace.itur_2100_PQ,
                                kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ),
                               ("HLG", CGColorSpace.itur_2100_HLG,
                                kCVImageBufferTransferFunction_ITU_R_2100_HLG)] {
    for (range, format, black, span) in [
        ("video", kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, 64.0, 876.0),
        ("full", kCVPixelFormatType_420YpCbCr10BiPlanarFullRange, 0.0, 1023.0)] {
        for (width, height) in [(1920, 1080), (3840, 2160)] {
            autoreleasepool {
                let bounds = CGRect(x: 0, y: 0, width: width, height: height)
                let colorSpace = CGColorSpace(name: space)!
                let input = makeBuffer(width: width, height: height, format: format)
                stamp(input, transfer: transfer)
                var scene = CIImage(color: CIColor(red: 4, green: 4, blue: 4, alpha: 1,
                                                   colorSpace: linear)!).cropped(to: bounds)
                scene = CIImage(color: CIColor(red: 3, green: 0.2, blue: 0.1, alpha: 1,
                                               colorSpace: linear)!)
                    .cropped(to: CGRect(x: 0, y: height / 2, width: width / 2, height: height / 2))
                    .composited(over: scene)
                context.render(scene, to: input, bounds: bounds, colorSpace: colorSpace)
                let decoded = CIImage(cvPixelBuffer: input, options: [.colorSpace: colorSpace])
                // Model a top-left object origin (400,800) in a 1920x1080 canvas.
                let scale = CGFloat(width) / 1920
                let origin = CGPoint(x: 400 * scale, y: CGFloat(1080 - 800 - bitmapHeight) * scale)
                let overlay = bitmapImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    .transformed(by: CGAffineTransform(translationX: origin.x, y: origin.y))
                let combined = overlay.composited(over: decoded)
                let output = makeBuffer(width: width, height: height, format: format)
                stamp(output, transfer: transfer)
                context.render(combined, to: output, bounds: bounds, colorSpace: colorSpace)
                let restored = CIImage(cvPixelBuffer: output, options: [.colorSpace: colorSpace])
                func point(_ x: Int, _ y: Int) -> (Int, Int) {
                    (Int(origin.x + CGFloat(x) * scale), Int(origin.y + CGFloat(y) * scale))
                }
                let opaque = point(24, 24), half = point(72, 24)
                let white = sample(restored, x: opaque.0, y: opaque.1)
                let halfAlpha = sample(restored, x: half.0, y: half.1)
                let original = sample(decoded, x: half.0, y: half.1)
                let grayBefore = sample(decoded, x: width * 3 / 4, y: height * 3 / 4)
                let grayAfter = sample(restored, x: width * 3 / 4, y: height * 3 / 4)
                let colorBefore = sample(decoded, x: width / 4, y: height * 3 / 4)
                let colorAfter = sample(restored, x: width / 4, y: height * 3 / 4)
                // Use the rasterized alpha/color, not an ideal floating 0.5 white.
                // An 8-bit premultiplied canvas has its own quantization boundary.
                let halfExpected = (0..<3).map {
                    bitmapHalfOverBlack[$0] + (1 - bitmapHalfAlpha) * original[$0]
                }
                let halfError = zip(halfAlpha.prefix(3), halfExpected).map { abs($0 - $1) }.max()!
                let idealHalfError = zip(halfAlpha.prefix(3), original.prefix(3).map { ($0 + 1) / 2 })
                    .map { abs($0 - $1) }.max()!
                let untouchedError = zip(grayBefore + colorBefore, grayAfter + colorAfter)
                    .map { abs($0 - $1) }.max()!
                var row: [String: Any] = ["transfer": name, "range": range,
                    "width": width, "height": height, "pixelFormat": format,
                    "opaqueWhiteLinearRGBA": white, "halfAlphaLinearRGBA": halfAlpha,
                    "halfAlphaExpectedRGB": halfExpected, "halfAlphaMaxError": halfError,
                    "idealFloatHalfWhiteMaxError": idealHalfError,
                    "rasterizedHalfAlpha": bitmapHalfAlpha,
                    "rasterizedHalfOverBlackLinearRGBA": bitmapHalfOverBlack,
                    "untouchedNeutralAndColorMaxError": untouchedError,
                    "sampleCoordinatesInCoreImageSpace": ["opaque": [opaque.0, opaque.1],
                                                           "halfAlpha": [half.0, half.1]],
                    "objectOriginInTopLeftCanvas": [400, 800], "sourceCanvas": [1920, 1080],
                    "bitmapSize": [bitmapWidth, bitmapHeight], "allGlyphsAvailable": allGlyphsAvailable]
                if name == "PQ" {
                    // CoreVideo CPU plane rows are top-down; CI coordinates are bottom-up.
                    let code = yCode(output, x: opaque.0, y: height - 1 - opaque.1)
                    row["opaqueWhiteY10"] = code
                    row["opaqueWhitePQEncodedNits"] = pqNits((Double(code) - black) / span)
                }
                if name == "PQ" && range == "video" && width == 1920 {
                    // A separate SDR backdrop keeps glyphs visible in the layout preview.
                    // This preview cannot prove HDR color or luminance on a display.
                    let layout = overlay.composited(over: CIImage(color:
                        CIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1, colorSpace: srgb)!)
                        .cropped(to: bounds))
                    let preview = context.createCGImage(layout, from: bounds, format: .RGBA8,
                                                        colorSpace: srgb)!
                    savePNG(preview, name: "layout-preview-sdr-only.png")
                }
                rows.append(row)
            }
            context.clearCaches()
        }
    }
}

// A per-pool threshold is not a global cap across retained format generations.
var pools: [CVPixelBufferPool] = []
var retainedSamples: [CMSampleBuffer] = []
var poolRows: [[String: Any]] = []
for format in [kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
               kCVPixelFormatType_420YpCbCr10BiPlanarFullRange] {
    var pool: CVPixelBufferPool?
    precondition(CVPixelBufferPoolCreate(nil, nil, [kCVPixelBufferWidthKey as String: 3840,
        kCVPixelBufferHeightKey as String: 2160, kCVPixelBufferPixelFormatTypeKey as String: format,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &pool) == 0)
    pools.append(pool!)
    for index in 0..<4 {
        var buffer: CVPixelBuffer?
        precondition(CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool!,
            [kCVPixelBufferPoolAllocationThresholdKey: 4] as CFDictionary, &buffer) == 0)
        var description: CMVideoFormatDescription?
        precondition(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
            imageBuffer: buffer!, formatDescriptionOut: &description) == noErr)
        var timing = CMSampleTimingInfo(duration: .invalid,
            presentationTimeStamp: CMTime(value: Int64(index), timescale: 24), decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        precondition(CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: buffer!,
            dataReady: true, makeDataReadyCallback: nil, refcon: nil,
            formatDescription: description!, sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer) == noErr)
        retainedSamples.append(sampleBuffer!)
    }
    var fifth: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool!,
        [kCVPixelBufferPoolAllocationThresholdKey: 4] as CFDictionary, &fifth)
    poolRows.append(["pixelFormat": format, "fifthAllocationStatus": status,
                     "thresholdEnforced": status == kCVReturnWouldExceedAllocationThreshold])
}
let retainedBytes = retainedSamples.reduce(0) {
    $0 + CVPixelBufferGetDataSize(CMSampleBufferGetImageBuffer($1)!)
}
let sampleCount = retainedSamples.count
retainedSamples.removeAll()
for pool in pools { CVPixelBufferPoolFlush(pool, .excessBuffers) }
let result: [String: Any] = ["scope": "Mac offline rasterized glyph/bitmap HDR probe",
    "appSourceChanged": false, "deviceOperated": false, "mediaRequests": 0,
    "inputFromGeneratedPGSDecoder": CommandLine.arguments.count == 3,
    "movieMediaTest": false, "panelLuminanceMeasured": false,
    "dolbyVisionMetadataValidated": false, "rows": rows,
    "retainedFormatGenerations": ["pools": poolRows, "heldSampleBuffers": sampleCount,
        "heldImageBufferBytes": retainedBytes, "samplesReleasedAtEnd": true,
        "perPoolThresholdIsGlobalMemoryCap": false]]
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try data.write(to: directory.appendingPathComponent("result-safe.json"))
print("Completed \(rows.count) glyph/bitmap cases and retained-generation counterexample")
