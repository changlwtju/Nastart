// Mac-only resource experiment. No App imports, product admission or iOS claims.
// A persistent single-key pool cannot retire into a second pool. Surface alias
// safety is checked independently from the allocation count and can still fail.
import Foundation
import CoreVideo
import CoreMedia
import IOSurface

guard CommandLine.arguments.count == 2 else { fatalError("Usage: swift hdr_pip_fixed_pool_probe.swift PRIVATE_OUTPUT_DIRECTORY") }
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
final class FixedBank {
    let width = 3840, height = 2160, limit = 4
    let format = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
    let pool: CVPixelBufferPool
    private(set) var ids = Set<IOSurfaceID>()
    private(set) var bytesByID: [IOSurfaceID: Int] = [:]
    init() {
        var created: CVPixelBufferPool?
        precondition(CVPixelBufferPoolCreate(nil,
            [kCVPixelBufferPoolMinimumBufferCountKey: limit,
             kCVPixelBufferPoolMaximumBufferAgeKey: 0] as CFDictionary,
            [kCVPixelBufferWidthKey: width, kCVPixelBufferHeightKey: height,
             kCVPixelBufferPixelFormatTypeKey: format,
             kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &created) == 0)
        pool = created!
    }
    func checkout(width: Int = 3840, height: Int = 2160,
                  format: OSType = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange) -> CVPixelBuffer? {
        guard width == self.width, height == self.height, format == self.format else { return nil }
        var result: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool,
            [kCVPixelBufferPoolAllocationThresholdKey: limit] as CFDictionary, &result) == 0,
              let result else { return nil }
        let surface = CVPixelBufferGetIOSurface(result)!.takeUnretainedValue()
        let id = IOSurfaceGetID(surface)
        ids.insert(id); bytesByID[id] = IOSurfaceGetAllocSize(surface)
        return result
    }
}
func sample(_ buffer: CVPixelBuffer) -> CMSampleBuffer {
    var description: CMVideoFormatDescription?
    precondition(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
        imageBuffer: buffer, formatDescriptionOut: &description) == 0)
    var result: CMSampleBuffer?
    var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
    precondition(CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: buffer,
        dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: description!,
        sampleTiming: &timing, sampleBufferOut: &result) == 0)
    return result!
}
func marker(_ buffer: CVPixelBuffer, write: UInt16? = nil) -> UInt16 {
    CVPixelBufferLockBaseAddress(buffer, []); defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let address = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!.assumingMemoryBound(to: UInt16.self)
    if let write { address.pointee = write }
    return address.pointee
}
let bank = FixedBank()
var rows: [[String: Any]] = []
var held = (0..<bank.limit).map { _ in sample(bank.checkout()!) }
precondition(bank.checkout() == nil)
rows.append(["case": "fourRealSamplesHeld", "fifthRejected": true,
             "uniqueSurfaces": bank.ids.count, "surfaceBytes": bank.bytesByID.values.reduce(0, +)])
for generation in 0..<12 {
    precondition(bank.checkout(width: 1920, height: 1080) == nil)
    precondition(bank.checkout(format: kCVPixelFormatType_420YpCbCr10BiPlanarFullRange) == nil)
    rows.append(["case": "configurationChangeRejected", "generation": generation,
                 "poolsCreated": 1, "uniqueSurfaces": bank.ids.count])
}
let originalSurfaceID = IOSurfaceGetID(CVPixelBufferGetIOSurface(CMSampleBufferGetImageBuffer(held[0])!)!.takeUnretainedValue())
var alias: CVPixelBuffer?
autoreleasepool {
    let original = CMSampleBufferGetImageBuffer(held[0])!
    _ = marker(original, write: 1234)
    let surface = CVPixelBufferGetIOSurface(original)!.takeUnretainedValue()
    var unmanaged: Unmanaged<CVPixelBuffer>?
    precondition(CVPixelBufferCreateWithIOSurface(nil, surface, nil, &unmanaged) == 0)
    alias = unmanaged!.takeRetainedValue()
    CVBufferRemoveAllAttachments(original)
    held.removeFirst()
}
var candidate: CVPixelBuffer? = bank.checkout()
let candidateID = candidate.map { IOSurfaceGetID(CVPixelBufferGetIOSurface($0)!.takeUnretainedValue()) }
if let candidate { _ = marker(candidate, write: 4321) }
let aliasUnchanged = marker(alias!) == 1234
rows.append(["case": "aliasHeldAfterOriginalWrapperReleased", "candidateAllocated": candidate != nil,
             "sameSurfaceReused": candidateID == originalSurfaceID,
             "oldAliasPixelsUnchangedAfterCandidateWrite": aliasUnchanged,
             "uniqueSurfaces": bank.ids.count, "poolsCreated": 1,
             "surfaceBytes": bank.bytesByID.values.reduce(0, +),
             "conclusion": aliasUnchanged ? "OnlyThisObservedAliasPreserved" : "AllocationBoundDoesNotProveFrameIsolation"])
alias = nil; candidate = nil; held.removeAll()
for _ in 0..<24 {
    autoreleasepool { let next = bank.checkout()!; _ = marker(next, write: 1000) }
}
precondition(bank.ids.count <= bank.limit)
rows.append(["case": "sameBankReuse24Generations", "uniqueSurfaces": bank.ids.count,
             "poolsCreated": 1, "retiredPools": 0,
             "surfaceBytes": bank.bytesByID.values.reduce(0, +)])
let output: [String: Any] = ["scope": "Mac single fixed-format pool only; no HDR pixels, App, dynamic formats or iOS budget verified",
    "cases": rows, "aliasIsolationObserved": aliasUnchanged,
    "productAdmission": false, "permanentAllocationTradeoff": true]
try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
    .write(to: directory.appendingPathComponent("fixed-bank-safe.json"))
print("Fixed pool experiment: \(bank.ids.count) surfaces; alias unchanged=\(aliasUnchanged); product admission=false")
