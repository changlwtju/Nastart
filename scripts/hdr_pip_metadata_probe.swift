// Mac-only VideoToolbox metadata experiment using tiny generated frames.
// No App/KSPlayer import, device access, network, media file or HDR rendering.
import Foundation
import CoreVideo
import CoreMedia
import VideoToolbox
import CryptoKit

func check(_ status: OSStatus, _ operation: String) throws {
    if status != 0 { throw NSError(domain: operation, code: Int(status)) }
}
func summary(_ values: [String: Any]) -> [String: Any] {
    values.mapValues { value -> [String: Any] in
        if let bytes = value as? Data {
            return ["type": "data", "bytes": bytes.count,
                    "sha256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()]
        }
        if let text = value as? String { return ["type": "string", "value": text] }
        return ["type": String(describing: type(of: value))]
    }
}
func extensions(_ description: CMFormatDescription) -> [String: Any] {
    summary(CMFormatDescriptionGetExtensions(description) as? [String: Any] ?? [:])
}
func attachments(_ buffer: CVPixelBuffer, _ mode: CVAttachmentMode) -> [String: Any] {
    summary(CVBufferCopyAttachments(buffer, mode) as? [String: Any] ?? [:])
}
func be16(_ value: UInt16) -> Data {
    var number = value.bigEndian; return withUnsafeBytes(of: &number) { Data($0) }
}
func be32(_ value: UInt32) -> Data {
    var number = value.bigEndian; return withUnsafeBytes(of: &number) { Data($0) }
}
let mastering = [UInt16(13250), 34500, 7500, 3000, 34000, 16000, 15635, 16450]
    .reduce(Data()) { $0 + be16($1) } + be32(10_000_000) + be32(50)
let contentLight = be16(1000) + be16(400)

final class Encoded {
    let lock = NSLock()
    var samples = [CMSampleBuffer]()
    var errors = [Int]()
    func accept(_ status: OSStatus, _ sample: CMSampleBuffer?) {
        lock.lock(); defer { lock.unlock() }
        if status != 0 { errors.append(Int(status)) }
        if let sample { samples.append(sample) }
    }
}
final class Decoded {
    let lock = NSLock()
    var rows = [[String: Any]]()
    var errors = [Int]()
    func accept(_ status: OSStatus, _ image: CVImageBuffer?, _ time: CMTime) {
        lock.lock(); defer { lock.unlock() }
        if status != 0 { errors.append(Int(status)) }
        guard let image else { return }
        var rebuilt: CMVideoFormatDescription?
        let rebuiltStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: nil, imageBuffer: image, formatDescriptionOut: &rebuilt)
        rows.append(["seconds": time.seconds,
            "pixelFormat": CVPixelBufferGetPixelFormatType(image),
            "width": CVPixelBufferGetWidth(image), "height": CVPixelBufferGetHeight(image),
            "propagatingAttachments": attachments(image, .shouldPropagate),
            "nonPropagatingAttachments": attachments(image, .shouldNotPropagate),
            "rebuiltDescriptionStatus": Int(rebuiltStatus),
            "rebuiltDescriptionExtensions": rebuilt.map(extensions) ?? [:]])
    }
}
let encodeCallback: VTCompressionOutputCallback = { ref, _, status, _, sample in
    guard let ref else { return }
    Unmanaged<Encoded>.fromOpaque(ref).takeUnretainedValue().accept(status, sample)
}
let decodeCallback: VTDecompressionOutputCallback = { ref, _, status, _, image, time, _ in
    guard let ref else { return }
    Unmanaged<Decoded>.fromOpaque(ref).takeUnretainedValue().accept(status, image, time)
}

func sourceBuffer(_ transfer: CFString, index: Int) throws -> CVPixelBuffer {
    var created: CVPixelBuffer?
    try check(CVPixelBufferCreate(nil, 192, 128, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
        [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &created), "sourceBuffer")
    let buffer = created!
    try check(CVPixelBufferLockBaseAddress(buffer, []), "lockSource")
    for plane in 0..<2 {
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
        let height = CVPixelBufferGetHeightOfPlane(buffer, plane)
        let pointer = CVPixelBufferGetBaseAddressOfPlane(buffer, plane)!
        memset(pointer, 0, stride * height)
        let width = CVPixelBufferGetWidthOfPlane(buffer, plane) * (plane == 0 ? 1 : 2)
        let pixels = pointer.assumingMemoryBound(to: UInt16.self)
        for y in 0..<height {
            for x in 0..<width { pixels[y * stride / 2 + x] = UInt16(plane == 0 ? 160 + index : 512) << 6 }
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])
    CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
    CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, transfer, .shouldPropagate)
    CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
    return buffer
}

func nalTypes(_ sample: CMSampleBuffer) throws -> [Int] {
    guard let format = CMSampleBufferGetFormatDescription(sample),
          let block = CMSampleBufferGetDataBuffer(sample) else {
        throw NSError(domain: "compressedDataMissing", code: -1)
    }
    var pointer: UnsafePointer<UInt8>?, size = 0, count = 0
    var headerLength: Int32 = 0
    try check(CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, parameterSetIndex: 0,
        parameterSetPointerOut: &pointer, parameterSetSizeOut: &size,
        parameterSetCountOut: &count, nalUnitHeaderLengthOut: &headerLength), "HEVCParameters")
    let length = CMBlockBufferGetDataLength(block)
    var bytes = [UInt8](repeating: 0, count: length)
    try bytes.withUnsafeMutableBytes { memory in
        try check(CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length,
            destination: memory.baseAddress!), "copyCompressedBytes")
    }
    guard (1...4).contains(headerLength) else { throw NSError(domain: "NALHeaderLength", code: Int(headerLength)) }
    var offset = 0, types = [Int]()
    while offset < length {
        guard offset + Int(headerLength) <= length else { throw NSError(domain: "NALTruncatedLength", code: offset) }
        var size = 0
        for _ in 0..<Int(headerLength) { size = size * 256 + Int(bytes[offset]); offset += 1 }
        guard size >= 2, offset + size <= length else { throw NSError(domain: "NALTruncatedPayload", code: offset) }
        types.append(Int((bytes[offset] >> 1) & 63)); offset += size
    }
    return types
}

func run(_ name: String, transfer: CFString, staticHDR: Bool, insertionMode: CFString) throws -> [String: Any] {
    let encoded = Encoded()
    var session: VTCompressionSession?
    try check(VTCompressionSessionCreate(allocator: nil, width: 192, height: 128,
        codecType: kCMVideoCodecType_HEVC,
        encoderSpecification: [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder as String: true] as CFDictionary,
        imageBufferAttributes: nil, compressedDataAllocator: nil,
        outputCallback: encodeCallback, refcon: Unmanaged.passUnretained(encoded).toOpaque(),
        compressionSessionOut: &session), "createHardwareEncoder")
    let encoder = session!
    defer { VTCompressionSessionInvalidate(encoder) }
    let properties: [(CFString, CFTypeRef)] = [
        (kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main10_AutoLevel),
        (kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse),
        (kVTCompressionPropertyKey_RealTime, kCFBooleanTrue),
        (kVTCompressionPropertyKey_HDRMetadataInsertionMode, insertionMode),
        (kVTCompressionPropertyKey_ColorPrimaries, kCVImageBufferColorPrimaries_ITU_R_2020),
        (kVTCompressionPropertyKey_TransferFunction, transfer),
        (kVTCompressionPropertyKey_YCbCrMatrix, kCVImageBufferYCbCrMatrix_ITU_R_2020)]
    for (key, value) in properties { try check(VTSessionSetProperty(encoder, key: key, value: value), "encoderProperty_\(key)") }
    var metadataStatuses = [String: Int]()
    if staticHDR {
        for (key, value) in [(kVTCompressionPropertyKey_MasteringDisplayColorVolume, mastering),
                             (kVTCompressionPropertyKey_ContentLightLevelInfo, contentLight)] {
            metadataStatuses[key as String] = Int(VTSessionSetProperty(encoder, key: key, value: value as CFData))
        }
    }
    try check(VTCompressionSessionPrepareToEncodeFrames(encoder), "prepareEncoder")
    for index in 0..<12 {
        let source = try sourceBuffer(transfer, index: index)
        try check(VTCompressionSessionEncodeFrame(encoder, imageBuffer: source,
            presentationTimeStamp: CMTime(value: Int64(index), timescale: 12),
            duration: CMTime(value: 1, timescale: 12), frameProperties: nil,
            sourceFrameRefcon: nil, infoFlagsOut: nil), "encodeFrame")
    }
    try check(VTCompressionSessionCompleteFrames(encoder, untilPresentationTimeStamp: .invalid), "completeEncoder")
    guard encoded.errors.isEmpty, encoded.samples.count == 12,
          let format = CMSampleBufferGetFormatDescription(encoded.samples[0]) else {
        throw NSError(domain: "encodedSampleCount", code: encoded.samples.count)
    }
    let decoded = Decoded()
    var record = VTDecompressionOutputCallbackRecord(decompressionOutputCallback: decodeCallback,
        decompressionOutputRefCon: Unmanaged.passUnretained(decoded).toOpaque())
    var decompression: VTDecompressionSession?
    try check(VTDecompressionSessionCreate(allocator: nil, formatDescription: format,
        decoderSpecification: [kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder as String: true] as CFDictionary,
        imageBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                               kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary,
        outputCallback: &record, decompressionSessionOut: &decompression), "createHardwareDecoder")
    let decoder = decompression!
    defer { VTDecompressionSessionInvalidate(decoder) }
    var hardware: Unmanaged<AnyObject>?
    let hardwareStatus = VTSessionCopyProperty(decoder, key: kVTDecompressionPropertyKey_UsingHardwareAcceleratedVideoDecoder,
        allocator: nil, valueOut: &hardware)
    let hardwareReported = hardware?.takeRetainedValue() as? Bool ?? false
    let generateStatus = VTSessionSetProperty(decoder, key: kVTDecompressionPropertyKey_GeneratePerFrameHDRDisplayMetadata, value: kCFBooleanFalse)
    let propagateStatus = VTSessionSetProperty(decoder, key: kVTDecompressionPropertyKey_PropagatePerFrameHDRDisplayMetadata, value: kCFBooleanTrue)
    for sample in encoded.samples {
        try check(VTDecompressionSessionDecodeFrame(decoder, sampleBuffer: sample, flags: [],
            frameRefcon: nil, infoFlagsOut: nil), "decodeFrame")
    }
    try check(VTDecompressionSessionFinishDelayedFrames(decoder), "finishDecoder")
    try check(VTDecompressionSessionWaitForAsynchronousFrames(decoder), "waitDecoder")
    guard decoded.errors.isEmpty, decoded.rows.count == 12 else {
        throw NSError(domain: "decodedFrameCount", code: decoded.rows.count)
    }
    let allNALTypes = try encoded.samples.flatMap(nalTypes)
    let counts = Dictionary(grouping: allNALTypes, by: { String($0) }).mapValues { $0.count }
    return ["fixture": name, "requestedStaticHDR": staticHDR,
        "encoderHDRMetadataInsertionMode": insertionMode as String,
        "decoderGenerateHDRMetadataFalseStatus": Int(generateStatus),
        "decoderPropagateHDRMetadataTrueStatus": Int(propagateStatus),
        "encodedNALTypeCounts": counts,
        "staticMetadataPropertyStatuses": metadataStatuses,
        "encodedSamples": encoded.samples.count, "compressedFormatExtensions": extensions(format),
        "hardwareDecodePropertyStatus": Int(hardwareStatus), "hardwareDecodeReported": hardwareReported,
        "hardwareEncoderRequired": true, "hardwareDecoderRequired": true,
        "decodedFrames": decoded.rows.count, "frames": decoded.rows]
}

guard CommandLine.arguments.count == 2 else { fatalError("Usage: swift hdr_pip_metadata_probe.swift PRIVATE_OUTPUT_DIRECTORY") }
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var result: [String: Any] = ["scope": "Mac generated Main10 VideoToolbox encode/decode metadata only",
    "appOrKSPlayerPath": false, "realMovieOrDolbyVisionMeasured": false,
    "iOSPiPOrHDRPresentationAccepted": false, "networkOrDeviceCommands": 0]
var fixtures = [[String: Any]]()
do {
    fixtures.append(try run("PQ_staticHDR_auto", transfer: kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ, staticHDR: true, insertionMode: kVTHDRMetadataInsertionMode_Auto))
    fixtures.append(try run("HLG_auto", transfer: kCVImageBufferTransferFunction_ITU_R_2100_HLG, staticHDR: false, insertionMode: kVTHDRMetadataInsertionMode_Auto))
    fixtures.append(try run("HLG_none", transfer: kCVImageBufferTransferFunction_ITU_R_2100_HLG, staticHDR: false, insertionMode: kVTHDRMetadataInsertionMode_None))
} catch {
    let failure = error as NSError
    result["failure"] = ["operation": failure.domain, "status": failure.code]
}
result["fixtures"] = fixtures
try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    .write(to: directory.appendingPathComponent("metadata-result.json"))
print(result["failure"] == nil ? "Three generated fixtures encoded/decoded; metadata inventory saved" : "Metadata probe blocked; failure saved")
if result["failure"] != nil { exit(1) }
