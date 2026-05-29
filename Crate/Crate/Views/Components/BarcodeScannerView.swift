import SwiftUI
import AVFoundation

/// Камера + AVFoundation barcode-scanner. Передаёт первый распознанный код в onCode.
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: ScannerVCDelegate {
        let parent: BarcodeScannerView
        init(parent: BarcodeScannerView) { self.parent = parent }
        func scanner(_ vc: ScannerVC, didFind code: String) { parent.onCode(code) }
        func scanner(_ vc: ScannerVC, didFail message: String) { parent.onError(message) }
    }
}

protocol ScannerVCDelegate: AnyObject {
    func scanner(_ vc: ScannerVC, didFind code: String)
    func scanner(_ vc: ScannerVC, didFail message: String)
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerVCDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReported = false
    private let frameOverlay = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
        addOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasReported = false
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        layoutOverlay()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            delegate?.scanner(self, didFail: "Камера недоступна на устройстве")
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    private func addOverlay() {
        frameOverlay.strokeColor = UIColor.systemYellow.cgColor
        frameOverlay.fillColor = UIColor.clear.cgColor
        frameOverlay.lineWidth = 3
        view.layer.addSublayer(frameOverlay)
    }

    private func layoutOverlay() {
        let w = view.bounds.width * 0.75
        let h: CGFloat = 110
        let rect = CGRect(x: (view.bounds.width - w) / 2,
                          y: (view.bounds.height - h) / 2,
                          width: w, height: h)
        frameOverlay.path = UIBezierPath(roundedRect: rect, cornerRadius: 10).cgPath
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasReported,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        hasReported = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        delegate?.scanner(self, didFind: code)
    }
}
