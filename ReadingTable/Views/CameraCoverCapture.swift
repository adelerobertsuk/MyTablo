import SwiftUI
import VisionKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct CameraCoverCaptureScreen: View {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if VNDocumentCameraViewController.isSupported {
                DocumentScannerRepresentable { image in
                    onCapture(image)
                    dismiss()
                } onCancel: {
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Scanning isn't available on this device.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                    Button("Close") { dismiss() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct DocumentScannerRepresentable: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                onCancel()
                return
            }
            onCapture(scan.imageOfPage(at: 0))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel()
        }
    }
}

struct RawPhotoCaptureScreen: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        Group {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                CameraRepresentable(onCapture: onCapture, onCancel: onCancel)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Camera isn't available on this device.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                    Button("Close", action: onCancel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Combines Take Photo and the background-removal review step into one continuous
/// full-screen presentation instead of two separately-dismissing/presenting covers.
/// Two `.fullScreenCover`s handing off to each other (dismiss camera, then present
/// review) raced on real hardware — camera teardown timing meant the review cover
/// sometimes never appeared, leaving a blank frozen screen. Switching content inside
/// a single cover has no modal transition to race.
struct CameraCaptureFlowScreen: View {
    var onConfirm: (_ image: UIImage, _ isCutout: Bool) -> Void
    var onCancel: () -> Void

    @State private var capturedImage: UIImage?

    var body: some View {
        if let capturedImage {
            BackgroundRemovalReviewScreen(originalImage: capturedImage, onConfirm: onConfirm, onCancel: onCancel)
        } else {
            RawPhotoCaptureScreen(onCapture: { image in
                capturedImage = image
            }, onCancel: onCancel)
        }
    }
}

enum BackgroundRemovalError: Error {
    case noSubjectFound
}

/// Cuts the main subject out of `image` with a transparent background, the same
/// technology behind Photos' "Lift Subject from Background." Runs off the main
/// thread since Vision's request handler blocks synchronously.
func removeBackground(from image: UIImage) async throws -> UIImage {
    guard let cgImage = image.cgImage else { throw BackgroundRemovalError.noSubjectFound }
    let orientation = CGImagePropertyOrientation(image.imageOrientation)

    let outputCGImage = try await Task.detached(priority: .userInitiated) {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw BackgroundRemovalError.noSubjectFound
        }

        let maskedPixelBuffer = try result.generateMaskedImage(
            ofInstances: result.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )

        let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
        guard let outputCGImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
            throw BackgroundRemovalError.noSubjectFound
        }
        return outputCGImage
    }.value

    return UIImage(cgImage: outputCGImage)
}

/// Take Photo / Choose from Library don't get Scan Cover's live corner-detection
/// UI, so a book photographed at even a slight angle keeps that skew all the way
/// through to the cutout. Best-effort corrects it the same way — detect the
/// book's 4 corners and warp them square — before anything else touches the
/// image. Silently returns the original if no confident rectangle is found,
/// since this is a background touch-up, not a user-facing action like
/// `removeBackground(from:)`.
func straightenedIfPossible(_ image: UIImage) async -> UIImage {
    guard let cgImage = image.cgImage else { return image }
    let orientation = CGImagePropertyOrientation(image.imageOrientation)

    return await Task.detached(priority: .userInitiated) {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.8
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 30
        request.maximumObservations = 3

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        guard (try? handler.perform([request])) != nil,
              let results = request.results, !results.isEmpty else {
            return image
        }

        func area(_ r: VNRectangleObservation) -> CGFloat {
            let width = hypot(r.topRight.x - r.topLeft.x, r.topRight.y - r.topLeft.y)
            let height = hypot(r.topLeft.x - r.bottomLeft.x, r.topLeft.y - r.bottomLeft.y)
            return width * height
        }
        guard let rectangle = results.max(by: { area($0) < area($1) }) else { return image }

        let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
        let extent = ciImage.extent

        func point(_ normalized: CGPoint) -> CGPoint {
            CGPoint(x: extent.origin.x + normalized.x * extent.width, y: extent.origin.y + normalized.y * extent.height)
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = point(rectangle.topLeft)
        filter.topRight = point(rectangle.topRight)
        filter.bottomLeft = point(rectangle.bottomLeft)
        filter.bottomRight = point(rectangle.bottomRight)

        guard let outputImage = filter.outputImage,
              let outputCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: outputCGImage)
    }.value
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Shown after Take Photo / Choose from Library so the user can preview and
/// optionally cut the subject out before it's saved as the book's cover.
struct BackgroundRemovalReviewScreen: View {
    let originalImage: UIImage
    var onConfirm: (_ image: UIImage, _ isCutout: Bool) -> Void
    var onCancel: () -> Void

    @State private var straightenedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var baseImage: UIImage { straightenedImage ?? originalImage }
    private var displayedImage: UIImage { processedImage ?? baseImage }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    CheckerboardBackground()
                    Image(uiImage: displayedImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                Button {
                    Task { await removeBackgroundTapped() }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(
                            processedImage == nil ? "Remove Background" : "Try Again",
                            systemImage: "wand.and.stars"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Cover Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        onConfirm(displayedImage, processedImage != nil)
                    }
                }
            }
            .task {
                straightenedImage = await straightenedIfPossible(originalImage)
            }
        }
    }

    private func removeBackgroundTapped() async {
        isProcessing = true
        errorMessage = nil
        do {
            processedImage = try await removeBackground(from: baseImage)
        } catch {
            errorMessage = "Couldn't find a clear subject to cut out — you can still use the original photo."
        }
        isProcessing = false
    }
}

private struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 12
            let rows = Int(size.height / squareSize) + 1
            let cols = Int(size.width / squareSize) + 1
            for row in 0..<rows {
                for col in 0..<cols where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(Color(.systemGray4)))
                }
            }
        }
        .background(Color(.systemGray6))
    }
}

private struct CameraRepresentable: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
