// Mac-only lifetime experiment. Not an App resource manager or iOS budget.
import Foundation
import CoreVideo
import CoreMedia
import AVFoundation
import IOSurface

final class Budget {
    private let lock = NSLock()
    let limit: Int
    private var used = 0
    private(set) var peak = 0
    init(limit: Int) { self.limit = limit }
    var reserved: Int { lock.lock(); defer { lock.unlock() }; return used }
    func acquire(_ bytes: Int) -> Reservation? {
        lock.lock(); defer { lock.unlock() }
        guard bytes > 0, used <= limit - bytes else { return nil }
        used += bytes
        peak = max(peak, used)
        return Reservation(budget: self, bytes: bytes)
    }
    fileprivate func release(_ bytes: Int) {
        lock.lock(); defer { lock.unlock() }
        precondition(used >= bytes)
        used -= bytes
    }
}
final class Reservation: NSObject {
    let budget: Budget
    let bytes: Int
    init(budget: Budget, bytes: Int) { self.budget = budget; self.bytes = bytes }
    deinit { budget.release(bytes) }
}

final class RetainedPool {
    static let tokenKey = "com.nastart.offline-pip-reservation" as CFString
    static let width = 3840, height = 2160, threshold = 4
    // Conservative experiment quota for these two observed 4K formats only.
    // It does not bound IOSurface/GPU metadata, working textures or entire App RSS.
    static let perBufferReservation = width * height * 4 + 1024 * 1024
    static let capacityReservation = threshold * perBufferReservation
    let pool: CVPixelBufferPool
    let reservation: Reservation
    init?(budget: Budget, format: OSType, injectCreationFailure: Bool = false) {
        guard let token = budget.acquire(Self.capacityReservation) else { return nil }
        if injectCreationFailure { return nil }
        var created: CVPixelBufferPool?
        let result = CVPixelBufferPoolCreate(nil, nil, [kCVPixelBufferWidthKey as String: Self.width,
            kCVPixelBufferHeightKey as String: Self.height,
            kCVPixelBufferPixelFormatTypeKey as String: format,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &created)
        guard result == 0, let created else { return nil }
        reservation = token
        pool = created
    }
    func buffer() -> CVPixelBuffer? {
        var result: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool,
            [kCVPixelBufferPoolAllocationThresholdKey: Self.threshold] as CFDictionary, &result) == 0,
            let result else { return nil }
        precondition(CVPixelBufferGetDataSize(result) <= Self.perBufferReservation)
        // CVBuffer retains this object. It owns no pool/buffer, avoiding a cycle.
        // A single token covers all possible buffers in this one bounded pool.
        CVBufferSetAttachment(result, Self.tokenKey, reservation, .shouldNotPropagate)
        return result
    }
}

func makeSample(_ buffer: CVPixelBuffer) -> CMSampleBuffer {
    var description: CMVideoFormatDescription?
    precondition(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
        imageBuffer: buffer, formatDescriptionOut: &description) == noErr)
    var sample: CMSampleBuffer?
    var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero,
                                    decodeTimeStamp: .invalid)
    precondition(CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: buffer,
        dataReady: true, makeDataReadyCallback: nil, refcon: nil,
        formatDescription: description!, sampleTiming: &timing, sampleBufferOut: &sample) == noErr)
    return sample!
}
func allocationBatch(_ pool: RetainedPool, count: Int) -> [CMSampleBuffer] {
    (0..<count).map { _ in makeSample(pool.buffer()!) }
}

let budget = Budget(limit: 150 * 1024 * 1024)
var rows: [[String: Any]] = []
var old: RetainedPool? = RetainedPool(budget: budget,
    format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
precondition(old != nil)
var samples = allocationBatch(old!, count: 4)
let actualBytes = samples.reduce(0) { $0 + CVPixelBufferGetDataSize(CMSampleBufferGetImageBuffer($1)!) }
precondition(old!.buffer() == nil)
rows.append(["case": "fourSamplesHeld", "reservedBytes": budget.reserved,
             "actualImageBufferBytes": actualBytes, "fifthBufferRejected": true])
old = nil
precondition(budget.reserved == RetainedPool.capacityReservation)
let refused = RetainedPool(budget: budget, format: kCVPixelFormatType_420YpCbCr10BiPlanarFullRange)
precondition(refused == nil)
rows.append(["case": "retiredPoolStillHeldBySamples", "reservedBytes": budget.reserved,
             "newFormatPoolDenied": true])
// Prove pixel-buffer lifetime rather than only CMSampleBuffer lifetime.
var independentlyHeldPixel: CVPixelBuffer? = CMSampleBufferGetImageBuffer(samples[0])
samples.removeAll()
precondition(budget.reserved == RetainedPool.capacityReservation)
rows.append(["case": "sampleReleasedButPixelBufferStillHeld", "reservedBytes": budget.reserved,
             "pixelBufferExists": independentlyHeldPixel != nil])
independentlyHeldPixel = nil
precondition(budget.reserved == 0)
rows.append(["case": "lastPixelReleased", "reservedBytes": budget.reserved])
autoreleasepool {
    let fresh = RetainedPool(budget: budget, format: kCVPixelFormatType_420YpCbCr10BiPlanarFullRange)
    precondition(fresh != nil)
    let sample = makeSample(fresh!.buffer()!)
    precondition(CMSampleBufferGetImageBuffer(sample) != nil)
    rows.append(["case": "retryAfterOldPixelsReleased", "reservedBytes": budget.reserved,
                 "newFormatPoolAdmitted": true])
}
precondition(budget.reserved == 0)
let failed = RetainedPool(budget: budget,
    format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, injectCreationFailure: true)
precondition(failed == nil && budget.reserved == 0)
rows.append(["case": "creationFailureReturnsReservation", "reservedBytes": budget.reserved])
// Repeat alternating formats while retaining the prior generation's real samples.
for index in 0..<12 {
    autoreleasepool {
        var pool: RetainedPool? = RetainedPool(budget: budget, format: index % 2 == 0
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_420YpCbCr10BiPlanarFullRange)
        precondition(pool != nil)
        var held = allocationBatch(pool!, count: 4)
        pool = nil
        precondition(RetainedPool(budget: budget,
            format: kCVPixelFormatType_420YpCbCr10BiPlanarFullRange) == nil)
        held.removeAll()
    }
    precondition(budget.reserved == 0)
}
rows.append(["case": "twelveAlternatingRetainedGenerations", "reservedBytes": budget.reserved,
             "peakReservationBytes": budget.peak, "allBlockedWhileOldSamplesHeld": true])
var displayLayerRows: [[String: Any]] = []
if CommandLine.arguments.dropFirst().contains("--display-layer") {
    var layer: AVSampleBufferDisplayLayer? = AVSampleBufferDisplayLayer()
    func observe(_ label: String) {
        displayLayerRows.append(["stage": label, "reservedBytes": budget.reserved,
            "layerStatus": layer.map { $0.status.rawValue } ?? -1,
            "readyForMoreData": layer?.isReadyForMoreMediaData ?? false,
            "errorCode": layer?.error.map { ($0 as NSError).code } ?? 0])
    }
    autoreleasepool {
        var pool: RetainedPool? = RetainedPool(budget: budget,
            format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        for _ in 0..<4 {
            let buffer = pool!.buffer()!
            CVPixelBufferLockBaseAddress(buffer, [])
            for plane in 0..<CVPixelBufferGetPlaneCount(buffer) {
                let count = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
                    * CVPixelBufferGetHeightOfPlane(buffer, plane) / 2
                CVPixelBufferGetBaseAddressOfPlane(buffer, plane)!
                    .assumingMemoryBound(to: UInt16.self)
                    .initialize(repeating: UInt16(plane == 0 ? 64 : 512) << 6, count: count)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            let sample = makeSample(buffer)
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample,
                createIfNecessary: true) as? [NSMutableDictionary], let attachment = attachments.first {
                attachment[kCMSampleAttachmentKey_DisplayImmediately] = true
            }
            layer!.enqueue(sample)
        }
        pool = nil
    }
    observe("producerPoolAndSamplesReleased")
    for index in 1...5 {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        observe("offscreenLayerRunLoop\(index)")
    }
    layer!.flushAndRemoveImage()
    observe("flushRequested")
    for index in 1...5 {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        observe("afterFlushRunLoop\(index)")
    }
    autoreleasepool { layer = nil }
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    observe("layerReleased")
}
var adversarialRows: [[String: Any]] = []
if CommandLine.arguments.dropFirst().contains("--adversarial-lifetime") {
    autoreleasepool {
        var pool: RetainedPool? = RetainedPool(budget: budget,
            format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        var original: CVPixelBuffer? = pool!.buffer()!
        let surface = CVPixelBufferGetIOSurface(original!)!.takeUnretainedValue()
        let originalSurfaceID = IOSurfaceGetID(surface)
        var alias: CVPixelBuffer?
        var unmanagedAlias: Unmanaged<CVPixelBuffer>?
        let status = CVPixelBufferCreateWithIOSurface(nil, surface, nil, &unmanagedAlias)
        alias = unmanagedAlias?.takeRetainedValue()
        precondition(status == 0 && alias != nil)
        precondition(CVPixelBufferGetIOSurface(alias!) != nil)
        let sameSurface = IOSurfaceGetID(CVPixelBufferGetIOSurface(alias!)!.takeUnretainedValue())
            == originalSurfaceID
        let copiedToken = CVBufferCopyAttachment(alias!, RetainedPool.tokenKey, nil) != nil
        pool = nil
        original = nil
        let reservedAfterOriginalRelease = budget.reserved
        var another: RetainedPool? = RetainedPool(budget: budget,
            format: kCVPixelFormatType_420YpCbCr10BiPlanarFullRange)
        adversarialRows.append(["case": "newCVWrapperSharesOldIOSurface",
            "sameIOSurface": sameSurface, "tokenCopiedToAlias": copiedToken,
            "oldSurfaceBytesStillHeld": IOSurfaceGetAllocSize(surface),
            "reservationAfterOriginalReleased": reservedAfterOriginalRelease,
            "newPoolAdmittedWhileAliasHeld": another != nil,
            "hardSurfaceLifetimeBudgetProven": false])
        another = nil
        alias = nil
    }
    precondition(budget.reserved == 0)
    autoreleasepool {
        var pool: RetainedPool? = RetainedPool(budget: budget,
            format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        var held: CVPixelBuffer? = pool!.buffer()!
        pool = nil
        precondition(budget.reserved > 0)
        CVBufferRemoveAttachment(held!, RetainedPool.tokenKey)
        adversarialRows.append(["case": "consumerRemovesPrivateAttachment",
            "originalPixelStillHeld": held != nil, "reservedBytes": budget.reserved,
            "imageBufferBytesStillHeld": CVPixelBufferGetDataSize(held!),
            "hardSurfaceLifetimeBudgetProven": false])
        held = nil
    }
    precondition(budget.reserved == 0)
}
let report: [String: Any] = ["scope": "Mac offline CVBuffer-attached shared reservation experiment",
    "AppOrKSPlayerChanged": false, "deviceOrMediaRequests": 0,
    "budgetBytes": budget.limit, "reservationBytesPerPool": RetainedPool.capacityReservation,
    "actualFourBufferBytes": actualBytes, "finalReservedBytes": budget.reserved,
    "peakReservedBytes": budget.peak, "peakWithinQuota": budget.peak <= budget.limit,
    "processRSSOrGPUMemoryBoundedByThisQuota": false,
    "productionBudgetChosen": false, "rows": rows,
    "adversarialLifetimeObservations": adversarialRows,
    "offscreenDisplayLayerObservations": displayLayerRows,
    "offscreenDisplayLayerIsNotIOSPiP": true]
print(String(decoding: try JSONSerialization.data(withJSONObject: report,
    options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
