import SwiftUI
import VisionKit
import Vision
import AVFoundation

struct BarcodeScannerScreen: View {
    var onScan: (String) -> Void
    var onCancel: () -> Void
    @State private var startError: String?

    var body: some View {
        ZStack(alignment: .top) {
            if let startError {
                VStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text(startError)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                    Button("Type the ISBN instead", action: onCancel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.05))
            } else if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                BarcodeScannerRepresentable(
                    onScan: onScan,
                    onStartError: { startError = $0 }
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Barcode scanning isn't available on this device. Type the ISBN instead.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                    Button("Close", action: onCancel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

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
        }
        .background(Color.black)
    }
}

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onStartError: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerHostController {
        let host = BarcodeScannerHostController()
        host.scanner.delegate = context.coordinator
        host.onStartError = onStartError
        return host
    }

    func updateUIViewController(_ controller: BarcodeScannerHostController, context: Context) {}

    static func dismantleUIViewController(_ controller: BarcodeScannerHostController, coordinator: Coordinator) {
        if controller.scanner.isScanning {
            controller.scanner.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var didFire = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didFire else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    didFire = true
                    if dataScanner.isScanning {
                        dataScanner.stopScanning()
                    }
                    onScan(payload)
                    break
                }
            }
        }
    }
}

final class BarcodeScannerHostController: UIViewController {
    let scanner: DataScannerViewController
    var onStartError: ((String) -> Void)?
    private var didStart = false

    init() {
        scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        scanner.view.frame = view.bounds
        scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        do {
            try scanner.startScanning()
        } catch {
            onStartError?("Couldn't start the camera. Type the ISBN instead.")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        if scanner.isScanning {
            scanner.stopScanning()
        }
        super.viewWillDisappear(animated)
    }
}

enum CameraAccess {
    static func request() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    static func turnTorchOff() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.isTorchModeSupported(.off) {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {}
    }
}
