//
//  CameraScannerView.swift
//  Brickognize
//
//  Created by Assistant on 8/20/25.
//

import SwiftUI
import AVFoundation
import UIKit
import SwiftData

struct CameraScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingCheck: Bool = false
    @State private var lastRecognizedName: String = ""
    @State private var lastRecognizedImageURL: URL?
    @State private var lastRecognizedId: String?
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            CameraPreview(capturedImageHandler: handleCapture(_:))
                .ignoresSafeArea()

            VStack {
                Spacer()
                captureButton
            }
            .padding(.bottom, 24)
        }
        .alert(isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Alert(title: Text("Error"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
        .overlay(alignment: .top) {
            if isProcessing {
                ProgressView("Recognizing...")
                    .padding(12)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 16)
            }
        }
        .overlay(alignment: .center) {
            if isPresentingCheck {
                VStack(spacing: 12) {
                    if let url = lastRecognizedImageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                                    .frame(maxWidth: 160, maxHeight: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure(_):
                                RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.2)).frame(width: 160, height: 120)
                            case .empty:
                                ProgressView().frame(width: 160, height: 120)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    Text(lastRecognizedName).font(.headline).foregroundStyle(.primary)
                    if let id = lastRecognizedId {
                        Text("ID: \(id)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button("Scan Another") { isPresentingCheck = false }
                        .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
            }
        }
    }

    private var captureButton: some View {
        Button(action: triggerCapture) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 84, height: 84)
                Circle().fill(.white).frame(width: 70, height: 70)
            }
        }
        .disabled(isProcessing)
        .accessibilityLabel("Capture")
    }

    private func triggerCapture() {
        NotificationCenter.default.post(name: .cameraTriggerCapture, object: nil)
    }

    @MainActor
    private func handleCapture(_ image: UIImage) {
        Task { @MainActor in
            isProcessing = true
        }
        Task {
            do {
                let result = try await APIClient.shared.recognizeBrick(from: image)
                await saveAndAcknowledge(result: result, thumbnail: image)
            } catch let apiError as APIClientError {
                await MainActor.run { self.errorMessage = apiError.description }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await MainActor.run { isProcessing = false }
        }
    }

    @MainActor
    private func saveAndAcknowledge(result: RecognitionResult, thumbnail: UIImage) async {
        let record = ScanRecord(
            recognizedName: result.name,
            recognizedId: result.id,
            confidence: result.confidence,
            thumbnailJPEGData: thumbnail.jpegData(compressionQuality: 0.6),
            remoteImageURL: result.imageURL?.absoluteString
        )
        modelContext.insert(record)
        do { try modelContext.save() } catch { }

        lastRecognizedName = result.name
        lastRecognizedImageURL = result.imageURL
        lastRecognizedId = result.id
        Feedback.playSuccess()
        isPresentingCheck = true
    }
}

fileprivate struct CameraPreview: UIViewControllerRepresentable {
    let capturedImageHandler: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.capturedImageHandler = capturedImageHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
    }
}

final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var capturedImageHandler: ((UIImage) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
        NotificationCenter.default.addObserver(self, selector: #selector(triggerCapture), name: .cameraTriggerCapture, object: nil)
    }

    private func setupSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureSession() }
                }
            }
        default:
            break
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else { return }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { return }
        session.addOutput(photoOutput)

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        if let layer = previewLayer {
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
        }

        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    @objc private func triggerCapture() {
        let settings = AVCapturePhotoSettings()
        if #available(iOS 13.0, *) {
            let max = photoOutput.maxPhotoQualityPrioritization
            if max == .quality {
                settings.photoQualityPrioritization = .quality
            } else if max == .balanced {
                settings.photoQualityPrioritization = .balanced
            } else {
                settings.photoQualityPrioritization = .speed
            }
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { print("Photo error: \(error)"); return }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        capturedImageHandler?(image)
    }
}

extension Notification.Name {
    static let cameraTriggerCapture = Notification.Name("cameraTriggerCapture")
}


