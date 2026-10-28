import AVFoundation
import SwiftUI
import TaimaCore
import UIKit

/// Live camera for labels that wrap around a tube or jar: every few frames
/// are read and combined, so turning the product slowly reads all of it.
@Observable
final class RotateScanSession {
    private(set) var fusion = LabelFusion()
    private(set) var bestImage: UIImage?
    private(set) var cameraState: CameraState = .starting
    @ObservationIgnored private let engine = RotateScanEngine()

    enum CameraState { case starting, running, denied, unavailable }

    var captureSession: AVCaptureSession { engine.session }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { cameraState = .denied; return }
        default:
            cameraState = .denied
            return
        }
        engine.onFrame = { [weak self] reading, image in
            Task { @MainActor in self?.apply(reading, image: image) }
        }
        cameraState = await engine.start() ? .running : .unavailable
    }

    func stop() { engine.stop() }

    private func apply(_ reading: LabelReading, image: UIImage?) {
        if !reading.detectedFields.isEmpty { fusion.add(reading) }
        if let image { bestImage = image }
    }
}

/// Owns the capture session and reads frames on its own queue.
private nonisolated final class RotateScanEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "taima.rotate-scan")
    private var lastRead = Date.distantPast
    private var configured = false
    private var bestScore = 0
    private let context = CIContext()
    /// The reading, and an image only when the frame is the clearest so far.
    var onFrame: (@Sendable (LabelReading, UIImage?) -> Void)?

    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                if !self.configured { self.configured = self.configure() }
                if self.configured { self.session.startRunning() }
                continuation.resume(returning: self.configured)
            }
        }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }

    private func configure() -> Bool {
        // A virtual multi-camera switches to macro on its own up close.
        guard let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        guard session.canAddInput(input) else { session.commitConfiguration(); return false }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return false }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        session.commitConfiguration()
        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            device.unlockForConfiguration()
        }
        return true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // About four readings a second; frames in between are dropped.
        guard Date.now.timeIntervalSince(lastRead) > 0.25, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastRead = .now
        let result = LabelScanner.read(pixelBuffer)
        // The frame with the most legible text, preferably one with the name,
        // becomes the photo; only then is an image made from it.
        let score = result.characters + (result.reading.name != nil ? 40 : 0)
        var image: UIImage?
        if score > bestScore {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                image = UIImage(cgImage: cgImage)
                bestScore = score
            }
        }
        onFrame?(result.reading, image)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

struct RotateScanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session = RotateScanSession()
    @State private var form = ProductForm.preroll
    @State private var finishing = false
    /// Called with the combined reading and the clearest frame.
    let onFinish: (LabelReading, UIImage?) -> Void

    private let fields: [(LabelField, String)] = [(.name, "Name"), (.thc, "THC"), (.grams, "Weight"), (.packedOn, "Packed"), (.productID, "Code")]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch session.cameraState {
            case .denied:
                ContentUnavailableView("Camera access is off", systemImage: "camera.badge.ellipsis",
                                       description: Text("Allow the camera for Taima in Settings to scan labels."))
                    .foregroundStyle(.white)
            case .unavailable:
                ContentUnavailableView("No camera", systemImage: "camera", description: Text("This device has no camera Taima can use."))
                    .foregroundStyle(.white)
            default:
                CameraPreview(session: session.captureSession).ignoresSafeArea()
                guide
            }
            VStack {
                topBar
                Spacer()
                bottomPanel
            }
            .padding()
        }
        .task { await session.start() }
        .onDisappear { session.stop() }
        .onChange(of: session.fusion.isComplete) { _, complete in
            guard complete, !finishing else { return }
            // A second more of frames lets the vote settle.
            finishing = true
            Task {
                try? await Task.sleep(for: .seconds(1))
                finish()
            }
        }
        .sensoryFeedback(.selection, trigger: session.fusion.found.count)
        .sensoryFeedback(.success, trigger: session.fusion.isComplete)
    }

    private var topBar: some View {
        HStack {
            Button("Cancel", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .controlSize(.large)
            Spacer()
            Picker("Product", selection: $form) {
                Text("Prerolls").tag(ProductForm.preroll)
                Text("Jar").tag(ProductForm.jar)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
    }

    private var guide: some View {
        RoundedRectangle(cornerRadius: 28)
            .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
            .frame(width: form == .preroll ? 150 : 240, height: form == .preroll ? 420 : 300)
            .animation(.snappy, value: form)
            .accessibilityHidden(true)
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: session.fusion.coverage)
                        .stroke(Theme.leafMid, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.snappy, value: session.fusion.coverage)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .symbolEffect(.rotate, isActive: session.cameraState == .running && !session.fusion.isComplete)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.fusion.isComplete ? "Got it" : "Turn it slowly")
                        .font(.headline)
                    Text(session.fusion.isComplete
                         ? "Everything important was read."
                         : "Hold the label inside the frame and rotate it all the way round.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(fields, id: \.0) { field, title in
                    let found = session.fusion.found.contains(field)
                    Label(title, systemImage: found ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(found ? AnyShapeStyle(Theme.leafMid.opacity(0.25)) : AnyShapeStyle(.white.opacity(0.08)), in: .capsule)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityLabel("\(title), \(found ? "read" : "not read yet")")
                }
            }
            Button {
                finish()
            } label: {
                Text(session.fusion.found.isEmpty ? "Waiting for the label…" : "Use what's read")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.solid)
            .controlSize(.large)
            .disabled(session.fusion.found.isEmpty)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .environment(\.colorScheme, .dark)
    }

    private func finish() {
        session.stop()
        var reading = session.fusion.reading
        if reading.form == nil { reading.form = form }
        onFinish(reading, session.bestImage)
        dismiss()
    }
}
