import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

struct RawPhotoCaptureScreen: View {
    var caption: String? = nil
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        Group {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                ZStack {
                    CameraRepresentable(onCapture: onCapture, onCancel: onCancel)
                        .ignoresSafeArea()
                    if let caption {
                        VStack {
                            Text(caption)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(.black.opacity(0.45), in: Capsule())
                                .padding(.top, 56)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
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

/// Camera shutter, then Cover Preview with Remove Background.
/// Kept in one screen so Apple's "Use Photo" cannot skip the cut-out step.
struct PhotoCoverFlowScreen: View {
    var onConfirm: (_ image: UIImage, _ isCutout: Bool, _ original: UIImage) -> Void
    var onCancel: () -> Void

    @State private var capturedImage: UIImage?

    var body: some View {
        if let capturedImage {
            BackgroundRemovalReviewScreen(originalImage: capturedImage) { finalImage, isCutout in
                onConfirm(finalImage, isCutout, capturedImage)
            } onCancel: {
                self.capturedImage = nil
            }
        } else {
            CoverCameraScreen(
                onCapture: { image in
                    capturedImage = image
                },
                onCancel: onCancel
            )
        }
    }
}

struct CoverCameraScreen: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            CoverCameraRepresentable(onCapture: onCapture)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Button("Cancel", action: onCancel)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.45), in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("Take a photo of the front cover.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.45), in: Capsule())
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

private struct CoverCameraRepresentable: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CoverCameraController {
        let controller = CoverCameraController()
        controller.onCapture = onCapture
        return controller
    }

    func updateUIViewController(_ uiViewController: CoverCameraController, context: Context) {
        uiViewController.onCapture = onCapture
    }
}

final class CoverCameraController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((UIImage) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "mytablo.cover-camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isCapturing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
        setupShutter()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CameraAccess.turnTorchOff()
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        super.viewWillDisappear(animated)
    }

    private func setupShutter() {
        let shutter = UIButton(type: .custom)
        shutter.backgroundColor = .white
        shutter.layer.cornerRadius = 36
        shutter.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        shutter.layer.borderWidth = 6
        shutter.accessibilityLabel = "Take photo"
        shutter.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        shutter.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shutter)
        NSLayoutConstraint.activate([
            shutter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            shutter.widthAnchor.constraint(equalToConstant: 72),
            shutter.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
    }

    @objc private func shutterTapped() {
        guard !isCapturing else { return }
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(.off) {
            settings.flashMode = .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { isCapturing = false }
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onCapture?(image)
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
        .trimmedToOpaqueContent()
        .uprightedCutoutIfNeeded()
}

/// Rotates a cut-out so the book sits upright. This is a 2D turn of the
/// silhouette, not a perspective warp — warping the original photo was
/// squashing covers that were already straight.
private extension UIImage {
    func uprightedCutoutIfNeeded() -> UIImage {
        guard let radians = opaqueUprightRotationRadians() else { return self }
        return rotatedKeepingAlpha(by: radians).trimmedToOpaqueContent()
    }

    func opaqueUprightRotationRadians() -> CGFloat? {
        let hull = opaqueSilhouetteHull(maxDimension: 240)
        guard hull.count >= 4, let box = minimumAreaBoundingBox(of: hull) else { return nil }

        var rotation = -box.angle
        if box.width > box.height {
            rotation += .pi / 2
        }
        while rotation > .pi / 2 { rotation -= .pi }
        while rotation < -.pi / 2 { rotation += .pi }

        let degrees = abs(rotation) * 180 / .pi
        guard degrees >= 1.5, degrees <= 50 else { return nil }
        return rotation
    }

    func opaqueSilhouetteHull(maxDimension: Int) -> [CGPoint] {
        guard let cgImage else { return [] }
        let srcW = cgImage.width
        let srcH = cgImage.height
        guard srcW > 8, srcH > 8 else { return [] }

        let scale = min(1, CGFloat(maxDimension) / CGFloat(max(srcW, srcH)))
        let width = max(8, Int((CGFloat(srcW) * scale).rounded()))
        let height = max(8, Int((CGFloat(srcH) * scale).rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var edgePoints: [CGPoint] = []
        let alphaThreshold: UInt8 = 48
        for y in 0..<height {
            var minX: Int?
            var maxX: Int?
            for x in 0..<width {
                let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
                guard alpha > alphaThreshold else { continue }
                if minX == nil { minX = x }
                maxX = x
            }
            if let minX, let maxX {
                edgePoints.append(CGPoint(x: minX, y: y))
                if maxX != minX {
                    edgePoints.append(CGPoint(x: maxX, y: y))
                }
            }
        }
        return convexHull(edgePoints)
    }

    func rotatedKeepingAlpha(by radians: CGFloat) -> UIImage {
        let rotatedRect = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians))
        let rotatedSize = CGSize(width: abs(rotatedRect.width), height: abs(rotatedRect.height))
        guard rotatedSize.width > 1, rotatedSize.height > 1 else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: rotatedSize, format: format).image { ctx in
            ctx.cgContext.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            ctx.cgContext.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }
}

private struct OrientedBounds {
    let angle: CGFloat
    let width: CGFloat
    let height: CGFloat
}

private func convexHull(_ points: [CGPoint]) -> [CGPoint] {
    let pts = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
    guard pts.count >= 3 else { return pts }

    func cross(_ origin: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x)
    }

    var lower: [CGPoint] = []
    for point in pts {
        while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
            lower.removeLast()
        }
        lower.append(point)
    }

    var upper: [CGPoint] = []
    for point in pts.reversed() {
        while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
            upper.removeLast()
        }
        upper.append(point)
    }

    lower.removeLast()
    upper.removeLast()
    return lower + upper
}

private func minimumAreaBoundingBox(of hull: [CGPoint]) -> OrientedBounds? {
    guard hull.count >= 3 else { return nil }
    var best: OrientedBounds?
    var bestArea = CGFloat.greatestFiniteMagnitude

    for index in 0..<hull.count {
        let current = hull[index]
        let next = hull[(index + 1) % hull.count]
        let dx = next.x - current.x
        let dy = next.y - current.y
        let length = hypot(dx, dy)
        guard length > 0.5 else { continue }

        let angle = atan2(dy, dx)
        let cosine = cos(-angle)
        let sine = sin(-angle)

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for point in hull {
            let x = point.x * cosine - point.y * sine
            let y = point.x * sine + point.y * cosine
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let area = width * height
        if area > 0, area < bestArea {
            bestArea = area
            best = OrientedBounds(angle: angle, width: width, height: height)
        }
    }
    return best
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
        request.minimumConfidence = 0.6
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

        let center = CGPoint(
            x: (rectangle.topLeft.x + rectangle.topRight.x + rectangle.bottomLeft.x + rectangle.bottomRight.x) / 4,
            y: (rectangle.topLeft.y + rectangle.topRight.y + rectangle.bottomLeft.y + rectangle.bottomRight.y) / 4
        )
        func expanded(_ normalized: CGPoint) -> CGPoint {
            let grow: CGFloat = 1.03
            return CGPoint(
                x: min(max(center.x + (normalized.x - center.x) * grow, 0), 1),
                y: min(max(center.y + (normalized.y - center.y) * grow, 0), 1)
            )
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = point(expanded(rectangle.topLeft))
        filter.topRight = point(expanded(rectangle.topRight))
        filter.bottomLeft = point(expanded(rectangle.bottomLeft))
        filter.bottomRight = point(expanded(rectangle.bottomRight))

        guard let outputImage = filter.outputImage,
              let outputCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: outputCGImage)
    }.value
}

struct CoverTextGuess {
    var title: String
    var author: String
}

/// Best-effort title and author from a cover photo so a failed ISBN lookup
/// does not mean typing everything by hand.
func recognizeCoverText(from image: UIImage) async -> CoverTextGuess? {
    guard let cgImage = image.cgImage else { return nil }
    let orientation = CGImagePropertyOrientation(image.imageOrientation)

    return await Task.detached(priority: .userInitiated) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observations = request.results, !observations.isEmpty else {
            return nil
        }

        struct Line {
            let text: String
            let y: CGFloat
            let height: CGFloat
        }

        let lines: [Line] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2, candidate.confidence > 0.35 else { return nil }
            return Line(text: text, y: observation.boundingBox.midY, height: observation.boundingBox.height)
        }
        .sorted { $0.y > $1.y }

        guard !lines.isEmpty else { return nil }

        let substantial = lines.filter { $0.text.filter(\.isLetter).count >= 3 }
        let source = substantial.isEmpty ? lines : substantial

        let topLines = source.filter { $0.y > 0.58 }
        let titleSource = topLines.isEmpty ? Array(source.prefix(2)) : topLines.sorted { $0.y > $1.y }

        var titleParts = [titleSource[0].text]
        if titleSource.count > 1 {
            let first = titleSource[0]
            let second = titleSource[1]
            if first.y - second.y < 0.14, second.height >= first.height * 0.35 {
                titleParts.append(second.text)
            }
        }

        let usedTitleText = Set(titleParts.map { $0.lowercased() })
        let bottomLines = source.filter { $0.y < 0.38 }
        let authorPool = bottomLines.isEmpty ? source : bottomLines
        let authorLine = authorPool.first { line in
            let lowered = line.text.lowercased()
            if usedTitleText.contains(lowered) { return false }
            if lowered.contains("introduction") { return false }
            if lowered.hasPrefix("by ") { return true }
            let words = line.text.split(whereSeparator: \.isWhitespace).filter { $0.count > 1 }
            guard (2...5).contains(words.count) else { return false }
            let letters = line.text.filter { $0.isLetter || $0.isWhitespace }
            return letters.count >= 6
        }

        var author = authorLine?.text ?? ""
        if author.lowercased().hasPrefix("by ") {
            author = String(author.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }

        return CoverTextGuess(title: titleParts.joined(separator: " "), author: author)
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

/// Shown after Take Photo / Choose from Photos so you can lift the book
/// off the background before it goes on the table.
struct BackgroundRemovalReviewScreen: View {
    let originalImage: UIImage
    var onConfirm: (_ image: UIImage, _ isCutout: Bool) -> Void
    var onCancel: () -> Void

    @Environment(\.palette) private var palette
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var displayedImage: UIImage { processedImage ?? originalImage }

    var body: some View {
        NavigationStack {
            ZStack {
                SanctuaryBackground()
                VStack(spacing: 20) {
                    ZStack {
                        if processedImage != nil {
                            CheckerboardBackground()
                        } else {
                            palette.card
                        }
                        Image(uiImage: displayedImage)
                            .resizable()
                            .scaledToFit()
                            .padding(18)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(palette.line, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Text(processedImage == nil
                         ? "Remove the background to leave just the book."
                         : "If the edge looks off, try again or use the original.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }

                    Button {
                        Haptics.tap()
                        Task { await removeBackgroundTapped() }
                    } label: {
                        HStack(spacing: 8) {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text(processedImage == nil ? "Remove background" : "Try again")
                            }
                        }
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(palette.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 52)

                    Spacer()
                }
            }
            .navigationTitle("Cover Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        Haptics.success()
                        onConfirm(displayedImage, processedImage != nil)
                    }
                }
            }
        }
    }

    private func removeBackgroundTapped() async {
        isProcessing = true
        errorMessage = nil
        do {
            processedImage = try await removeBackground(from: originalImage)
            Haptics.success()
        } catch {
            errorMessage = "Couldn't find a clear book to cut out. You can still use the original photo."
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
        CameraAccess.turnTorchOff()
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraFlashMode = .off
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
