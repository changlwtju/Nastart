// Mac-only admission/callback information-loss experiment. No App imports,
// rendering, network, device control, or product metadata policy is installed.
// Every context below is synthetic; actual decoder/CVBuffer metadata is unknown.
import Foundation
import CoreVideo

enum Inventory { case unknown, noDynamicMetadata, dolbyVision, hdr10Plus, vivid }
enum StaticMetadata { case unknown, verifiedAbsent, opaqueUnhandled }
struct FrameContext {
    var currentPlan = true
    var hasCue = true
    var isDovi: Bool? = false
    var dynamic: Inventory = .noDynamicMetadata
    var staticHDR: StaticMetadata = .verifiedAbsent
    var sourceDescriptionKnown = true
}
struct Decision {
    let reason: String
    let contextEligible: Bool
}

// Deliberately strict experimental predicate. An eligible context is NOT
// permission to compose: white calibration, resource ownership, output sample,
// and actual iOS acceptance remain separate unresolved gates.
func classify(_ context: FrameContext, inspect: () -> [String: String]) -> Decision {
    func reject(_ reason: String) -> Decision { Decision(reason: reason, contextEligible: false) }
    guard context.currentPlan else { return reject("retiredPlan") }
    guard context.hasCue else { return reject("noCue") }
    guard let isDovi = context.isDovi else { return reject("unknownFrameDolbyIdentity") }
    guard !isDovi else { return reject("dolbyVisionUnhandled") }
    switch context.dynamic {
    case .unknown: return reject("unknownDynamicInventory")
    case .dolbyVision: return reject("dolbyVisionUnhandled")
    case .hdr10Plus: return reject("hdr10PlusUnhandled")
    case .vivid: return reject("vividUnhandled")
    case .noDynamicMetadata: break
    }
    switch context.staticHDR {
    case .unknown: return reject("unknownStaticHDRContext")
    case .opaqueUnhandled: return reject("staticHDRUnhandled")
    case .verifiedAbsent: break
    }
    guard context.sourceDescriptionKnown else { return reject("unknownSourceDescriptionContext") }
    let tags = inspect()
    guard [String(kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange),
           String(kCVPixelFormatType_420YpCbCr10BiPlanarFullRange)].contains(tags["format"] ?? "")
    else { return reject("unsupportedPixelFormat") }
    guard tags["primaries"] == kCVImageBufferColorPrimaries_ITU_R_2020 as String,
          tags["matrix"] == kCVImageBufferYCbCrMatrix_ITU_R_2020 as String
    else { return reject("missingOrUnsupportedColorTags") }
    guard [kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String,
           kCVImageBufferTransferFunction_ITU_R_2100_HLG as String].contains(tags["transfer"] ?? "")
    else { return reject("unknownOrUnsupportedTransfer") }
    return Decision(reason: "contextOnlyEligibleNotProductAdmission", contextEligible: true)
}

func makeBuffer(format: OSType = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                transfer: CFString? = kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ,
                primaries: CFString? = kCVImageBufferColorPrimaries_ITU_R_2020) -> CVPixelBuffer {
    var result: CVPixelBuffer?
    precondition(CVPixelBufferCreate(nil, 16, 16, format,
        [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &result) == 0)
    let buffer = result!
    if let transfer { CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, transfer, .shouldPropagate) }
    if let primaries { CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, primaries, .shouldPropagate) }
    CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey,
                          kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
    return buffer
}
func tags(_ buffer: CVPixelBuffer) -> [String: String] {
    func value(_ key: CFString) -> String? {
        CVBufferCopyAttachment(buffer, key, nil).map { String(describing: $0) }
    }
    var result = ["format": String(CVPixelBufferGetPixelFormatType(buffer))]
    result["primaries"] = value(kCVImageBufferColorPrimariesKey)
    result["transfer"] = value(kCVImageBufferTransferFunctionKey)
    result["matrix"] = value(kCVImageBufferYCbCrMatrixKey)
    return result
}

guard CommandLine.arguments.count == 2 else { fatalError("Usage: swift hdr_pip_context_probe.swift PRIVATE_OUTPUT_DIRECTORY") }
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let pq = makeBuffer()
struct Case {
    let name: String
    let buffer: CVPixelBuffer
    let context: FrameContext
    let expected: String
}
var cases = [Case]()
func add(_ name: String, buffer: CVPixelBuffer? = nil, expected: String,
         change: (inout FrameContext) -> Void = { _ in }) {
    var context = FrameContext(); change(&context)
    cases.append(Case(name: name, buffer: buffer ?? pq, context: context, expected: expected))
}
add("retiredOwnerBeforeMetadataRead", expected: "retiredPlan") { $0.currentPlan = false }
add("noCueBeforeMetadataRead", expected: "noCue") { $0.hasCue = false }
add("currentCallbackLacksFrameIdentity", expected: "unknownFrameDolbyIdentity") {
    $0.isDovi = nil; $0.dynamic = .unknown; $0.staticHDR = .unknown; $0.sourceDescriptionKnown = false
}
add("noDoviFlagIsNotDynamicInventory", expected: "unknownDynamicInventory") { $0.dynamic = .unknown }
add("explicitDVWithPQTags", expected: "dolbyVisionUnhandled") { $0.isDovi = true }
add("explicitDVWithoutTransfer", buffer: makeBuffer(transfer: nil), expected: "dolbyVisionUnhandled") { $0.isDovi = true }
add("DVSideDataWithoutTrackFlag", expected: "dolbyVisionUnhandled") { $0.dynamic = .dolbyVision }
add("HDR10PlusSideData", expected: "hdr10PlusUnhandled") { $0.dynamic = .hdr10Plus }
add("vividSideData", expected: "vividUnhandled") { $0.dynamic = .vivid }
add("staticContextAbsentFromCallback", expected: "unknownStaticHDRContext") { $0.staticHDR = .unknown }
add("staticEDROpaqueUnhandled", expected: "staticHDRUnhandled") { $0.staticHDR = .opaqueUnhandled }
add("sourceDescriptionMissing", expected: "unknownSourceDescriptionContext") { $0.sourceDescriptionKnown = false }
add("transferMissing", buffer: makeBuffer(transfer: nil), expected: "unknownOrUnsupportedTransfer")
add("transfer709IsNotHDRProbeAdmission", buffer: makeBuffer(transfer: kCVImageBufferTransferFunction_ITU_R_709_2), expected: "unknownOrUnsupportedTransfer")
add("primariesMissing", buffer: makeBuffer(primaries: nil), expected: "missingOrUnsupportedColorTags")
add("eightBitRejected", buffer: makeBuffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), expected: "unsupportedPixelFormat")
for (name, transfer) in [("PQ", kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ),
                          ("HLG", kCVImageBufferTransferFunction_ITU_R_2100_HLG)] {
    for (range, format) in [("video", kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange),
                            ("full", kCVPixelFormatType_420YpCbCr10BiPlanarFullRange)] {
        add("explicitKnownFixture_\(name)_\(range)", buffer: makeBuffer(format: format, transfer: transfer),
            expected: "contextOnlyEligibleNotProductAdmission")
    }
}

var rows = [[String: Any]]()
for fixture in cases {
    let originalTags = tags(fixture.buffer)
    var metadataReads = 0, attemptedRenderers = 0
    let decision = classify(fixture.context) { metadataReads += 1; return tags(fixture.buffer) }
    precondition(decision.reason == fixture.expected, "Unexpected classification: \(fixture.name)")
    // An injected renderer failure must preserve the identical source object;
    // rejection must not call the renderer at all. No output is allocated here.
    func failingRenderer() -> CVPixelBuffer? { attemptedRenderers += 1; return nil }
    let output = decision.contextEligible ? failingRenderer() ?? fixture.buffer : fixture.buffer
    precondition(output === fixture.buffer && tags(output) == originalTags)
    precondition(attemptedRenderers == (decision.contextEligible ? 1 : 0))
    if fixture.name == "retiredOwnerBeforeMetadataRead" || fixture.name == "noCueBeforeMetadataRead" {
        precondition(metadataReads == 0)
    }
    rows.append(["case": fixture.name, "reason": decision.reason,
                 "contextOnlyEligible": decision.contextEligible, "metadataReads": metadataReads,
                 "rendererAttempts": attemptedRenderers, "originalObjectAndTagsPreserved": true])
}
// A simulated non-DV frame and DV frame can project to the SAME buffer/time
// callback arguments. This proves insufficiency of that interface, not the
// attachment contents of a real decoder, nor actual Dolby output behavior.
let projectedNonDV = (pq, 42.0), projectedDV = (pq, 42.0)
var nonDVContext = FrameContext(), dvContext = FrameContext()
dvContext.isDovi = true
let nonDVDecision = classify(nonDVContext) { tags(projectedNonDV.0) }
let dvDecision = classify(dvContext) { tags(projectedDV.0) }
precondition(projectedNonDV.0 === projectedDV.0 && projectedNonDV.1 == projectedDV.1)
precondition(nonDVDecision.contextEligible && !dvDecision.contextEligible)
let result: [String: Any] = ["scope": "Mac synthetic context experiment only",
    "cases": rows, "caseCount": rows.count,
    "samePixelBufferAndTimeCanRepresentDifferentSimulatedFrameContexts": true,
    "sameArgumentContextDecisions": [nonDVDecision.reason, dvDecision.reason],
    "actualHardwareMetadataMeasured": false, "productPolicyInstalled": false,
    "outputBuffersAllocated": 0, "resourceOwnershipSolved": false,
    "iOSPiPOrHDRPresentationAccepted": false]
try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    .write(to: directory.appendingPathComponent("context-result.json"))
print("Context counterexamples: \(rows.count) passed; no output rendering or product admission")
