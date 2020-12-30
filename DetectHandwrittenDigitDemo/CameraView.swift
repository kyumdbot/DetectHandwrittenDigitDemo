//
//  CameraView.swift
//  DetectHandwrittenDigitDemo
//
//  Created by Wei-Cheng Ling on 2020/12/21.
//

import SwiftUI
import AppKit
import Vision
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins


struct CameraView: NSViewRepresentable {
    typealias NSViewType = MyDetectHandwrittenDigitCameraView
    
    @Binding var digit : Int?
    
    func makeNSView(context: Self.Context) -> Self.NSViewType {
        let cameraView = MyDetectHandwrittenDigitCameraView()
        cameraView.delegate = context.coordinator
        return cameraView
    }
    
    func updateNSView(_ nsView: Self.NSViewType, context: Self.Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator($digit)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MyDetectHandwrittenDigitCameraViewDelegate {
        var digit: Binding<Int?>
        
        init(_ digit: Binding<Int?>) {
            self.digit = digit
        }
        
        func detectedHandwrittenDigit(_ digit: Int?) {
            self.digit.wrappedValue = digit
        }
    }
}


/*
 * - MyDetectHandwrittenDigitCameraViewDelegate
 */
protocol MyDetectHandwrittenDigitCameraViewDelegate: AnyObject {
    func detectedHandwrittenDigit(_ digit: Int?)
}


/*
 * - MyDetectHandwrittenDigitCameraView
 */
class MyDetectHandwrittenDigitCameraView: NSView, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var delegate : MyDetectHandwrittenDigitCameraViewDelegate?
    
    var cameraDevices : [AVCaptureDevice]!
    var currentCameraDevice : AVCaptureDevice!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var videoSession : AVCaptureSession!
    
    var camerasPopUpButton : NSPopUpButton!
    var cameraStackView : NSStackView!
    
    var digitLabel : NSTextField!
    var imageView : NSImageView!
    var digitStackView : NSStackView!
    
    var contourWidthStepper : NSStepper!
    var contourWidthTitleLabel : NSTextField!
    var contourWidthTextField : NSTextField!
    var contourWidthStackView : NSStackView!
    
    var digitImageWidthStepper : NSStepper!
    var digitImageWidthTitleLabel : NSTextField!
    var digitImageWidthTextField : NSTextField!
    var digitImageWidthStackView : NSStackView!
    
    var croppingBorderWidthStepper : NSStepper!
    var croppingBorderWidthTitleLabel : NSTextField!
    var croppingBorderWidthTextField : NSTextField!
    var croppingBorderWidthStackView : NSStackView!
    
    
    var hasCameraDevice = false
    var rectangleLayers = [CAShapeLayer]()
    var digitRecognitionRequests = [VNRequest]()
    
    var isGaussianBlur = true
    var isRemoveBorderContourLabel = false
    var contourWidth : CGFloat = 15
    var digitImageWidth : Int = 40
    var digitConfidence : Double = 0.75
    var croppingBorderWidth : Int = 0
    
    
    
    // MARK: - Init
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        // get camera devices
        cameraDevices = getCameraDevices()
        
        // setup UI components
        setupUIComponents()
        
        // setup camera
        setupDefaultCamera()
        
        // setup CoreML Model
        setupHandwrittenDigitDetectionModel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Setup
    
    func setupUIComponents() {
        setupCameraUIComponents()
        setupContourWidthUIComponents()
        setupDigitImageWidthUIComponents()
        setupCroppingBorderWidthUIComponents()
        
        let stackView = NSStackView(views: [cameraStackView,
                                            contourWidthStackView,
                                            digitImageWidthStackView,
                                            croppingBorderWidthStackView])
        stackView.spacing = 2
        stackView.wantsLayer = true
        stackView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            camerasPopUpButton.widthAnchor.constraint(equalToConstant: 116),
            contourWidthTextField.widthAnchor.constraint(equalToConstant: 32),
            digitImageWidthTextField.widthAnchor.constraint(equalToConstant: 40),
            croppingBorderWidthTextField.widthAnchor.constraint(equalToConstant: 32),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 32)
        ])

        setupDigitUIComponents()
        digitStackView.frame.origin = CGPoint(x: 10, y: 42)
        self.addSubview(digitStackView)
    }
    
    
    func setupCameraUIComponents() {
        setupCamerasPopUpButton()
        
        cameraStackView = NSStackView(views: [camerasPopUpButton])
        //cameraStackView.spacing = 6
        cameraStackView.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        cameraStackView.setCustomSpacing(11, after: camerasPopUpButton)
        
        cameraStackView.wantsLayer = true
        cameraStackView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    func setupCamerasPopUpButton() {
        camerasPopUpButton = NSPopUpButton()
                
        if cameraDevices.count <= 0 {
            camerasPopUpButton.addItem(withTitle: "No Camera Device")
            hasCameraDevice = false
            return
        }
        
        for device in cameraDevices {
            camerasPopUpButton.addItem(withTitle: "\(device.localizedName)")
        }
        hasCameraDevice = true
        
        camerasPopUpButton.target = self
        camerasPopUpButton.action = #selector(onSelectCamerasPopUpButton)
    }
    
    
    func setupContourWidthUIComponents() {
        contourWidthTitleLabel = NSTextField(labelWithString: "Contour Size :")
        contourWidthTitleLabel.textColor = .labelColor
        contourWidthTitleLabel.font = NSFont.systemFont(ofSize: 14)
        
        contourWidthTextField = NSTextField()
        contourWidthTextField.alignment = .center
        contourWidthTextField.stringValue = "\(Int(contourWidth))"
        contourWidthTextField.isEditable = false
        
        contourWidthStepper = NSStepper()
        contourWidthStepper.minValue = 5.0
        contourWidthStepper.maxValue = 50.0
        contourWidthStepper.increment = 1
        contourWidthStepper.valueWraps = false
        contourWidthStepper.doubleValue = Double(contourWidth)

        contourWidthStepper.target = self
        contourWidthStepper.action = #selector(onChangeContourWidthStepper)
        
        contourWidthStackView = NSStackView(views: [contourWidthTitleLabel, contourWidthTextField, contourWidthStepper])
        contourWidthStackView.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        
        contourWidthStackView.wantsLayer = true
        contourWidthStackView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    
    func setupDigitImageWidthUIComponents() {
        digitImageWidthTitleLabel = NSTextField(labelWithString: "Image Width :")
        digitImageWidthTitleLabel.textColor = .labelColor
        digitImageWidthTitleLabel.font = NSFont.systemFont(ofSize: 14)
        
        digitImageWidthTextField = NSTextField()
        digitImageWidthTextField.alignment = .center
        digitImageWidthTextField.stringValue = "\(digitImageWidth)"
        digitImageWidthTextField.isEditable = false
        
        digitImageWidthStepper = NSStepper()
        digitImageWidthStepper.minValue = 20
        digitImageWidthStepper.maxValue = 100
        digitImageWidthStepper.increment = 1
        digitImageWidthStepper.valueWraps = false
        digitImageWidthStepper.integerValue = digitImageWidth

        digitImageWidthStepper.target = self
        digitImageWidthStepper.action = #selector(onChangeDigitImageWidthStepper)
        
        digitImageWidthStackView = NSStackView(views: [digitImageWidthTitleLabel, digitImageWidthTextField, digitImageWidthStepper])
        digitImageWidthStackView.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        
        digitImageWidthStackView.wantsLayer = true
        digitImageWidthStackView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    
    func setupCroppingBorderWidthUIComponents() {
        croppingBorderWidthTitleLabel = NSTextField(labelWithString: "Crop Border :")
        croppingBorderWidthTitleLabel.textColor = .labelColor
        croppingBorderWidthTitleLabel.font = NSFont.systemFont(ofSize: 14)
        
        croppingBorderWidthTextField = NSTextField()
        croppingBorderWidthTextField.alignment = .center
        croppingBorderWidthTextField.stringValue = "\(croppingBorderWidth)"
        croppingBorderWidthTextField.isEditable = false
        
        croppingBorderWidthStepper = NSStepper()
        croppingBorderWidthStepper.minValue = 0
        croppingBorderWidthStepper.maxValue = 50
        croppingBorderWidthStepper.increment = 1
        croppingBorderWidthStepper.valueWraps = false
        croppingBorderWidthStepper.integerValue = croppingBorderWidth
        
        croppingBorderWidthStepper.target = self
        croppingBorderWidthStepper.action = #selector(onChangeCroppingBorderWidthStepper)
        
        croppingBorderWidthStackView = NSStackView(views: [croppingBorderWidthTitleLabel,
                                                           croppingBorderWidthTextField,
                                                           croppingBorderWidthStepper])
        croppingBorderWidthStackView.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        
        croppingBorderWidthStackView.wantsLayer = true
        croppingBorderWidthStackView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    
    func setupDigitUIComponents() {
        setupDigitLabel()
        setupImageView()
        
        digitStackView = NSStackView(views: [digitLabel, imageView])
        digitStackView.orientation = .vertical
    }
    
    func setupDigitLabel() {
        digitLabel = NSTextField(labelWithString: "")
        digitLabel.textColor = NSColor.red
        digitLabel.font = NSFont.boldSystemFont(ofSize: 40)
    }
    
    func setupImageView() {
        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
    }
    
    
    func setupDefaultCamera() {
        if cameraDevices.count > 0 {
            if let device = cameraDevices.first {
                startUpCameraDevice(device)
            }
        }
    }
    
    
    // MARK: - Action
    
    @objc func onSelectCamerasPopUpButton(_ sender: NSPopUpButton) {
        if !hasCameraDevice { return }
        
        print("\(sender.indexOfSelectedItem) : \(sender.titleOfSelectedItem ?? "")")
        
        if sender.indexOfSelectedItem < cameraDevices.count {
            let device = cameraDevices[sender.indexOfSelectedItem]
            startUpCameraDevice(device)
        }
    }
    
    @objc func onChangeVideoMirrorSwitch(_ sender: NSSwitch) {
        if previewLayer == nil { return }
        
        switch sender.state {
        case .off:
            previewLayer.connection?.isVideoMirrored = false
        case .on:
            previewLayer.connection?.isVideoMirrored = true
        default:
            break
        }
    }
    
    @objc func onChangeGaussianBlurSwitch(_ sender: NSSwitch) {
        switch sender.state {
        case .off:
            isGaussianBlur = false
        case .on:
            isGaussianBlur = true
        default:
            break
        }
    }
    
    @objc func onChangeContourWidthStepper(_ sender: NSStepper) {
        contourWidth = CGFloat(sender.doubleValue)
        contourWidthTextField.stringValue = "\(Int(sender.doubleValue))"
    }
    
    @objc func onChangeDigitImageWidthStepper(_ sender: NSStepper) {
        digitImageWidth = sender.integerValue
        digitImageWidthTextField.stringValue = "\(digitImageWidth)"
    }
    
    @objc func onChangeCroppingBorderWidthStepper(_ sender: NSStepper) {
        if sender.integerValue < Int(digitImageWidth/2) {
            croppingBorderWidth = sender.integerValue
            croppingBorderWidthTextField.stringValue = "\(croppingBorderWidth)"
        }
    }
    
    
    // MARK: - Camera Devices
        
    func getCameraDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                                                                mediaType: .video,
                                                                position: .unspecified)
        return discoverySession.devices
    }
    
    func startUpCameraDevice(_ device: AVCaptureDevice) {
        if prepareCamera(device) {
            startSession()
        }
    }
    
    func prepareCamera(_ device: AVCaptureDevice) -> Bool {
        setCameraFrameRate(20, device: device)
        currentCameraDevice = device
        
        videoSession = AVCaptureSession()
        videoSession.sessionPreset = AVCaptureSession.Preset.vga640x480
        previewLayer = AVCaptureVideoPreviewLayer(session: videoSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if videoSession.canAddInput(input) {
                videoSession.addInput(input)
            }
            
            if let previewLayer = self.previewLayer {
                if let isVideoMirroringSupported = previewLayer.connection?.isVideoMirroringSupported,
                   isVideoMirroringSupported == true
                {
                    previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
                    previewLayer.connection?.isVideoMirrored = false
                }
                
                previewLayer.frame = self.bounds
                self.layer = previewLayer
                self.wantsLayer = true
            }
        } catch {
            print(error.localizedDescription)
            return false
        }
            
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        
        if videoSession.canAddOutput(videoOutput) {
            videoSession.addOutput(videoOutput)
        }
        return true
    }
    
    func setCameraFrameRate(_ frameRate: Float64, device: AVCaptureDevice) {
        print("Video Supported Frame Rate Ranges: \(device.activeFormat.videoSupportedFrameRateRanges)")
        
        for frameRateRange in device.activeFormat.videoSupportedFrameRateRanges.reversed() {
            if frameRateRange.minFrameRate == frameRateRange.maxFrameRate {
                if Int(frameRate) == Int(frameRateRange.minFrameRate) {
                    do {
                        try device.lockForConfiguration()
                        device.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
                        device.activeVideoMaxFrameDuration = frameRateRange.maxFrameDuration
                        device.unlockForConfiguration()
                        print("setCameraFrameRate: \(Int(frameRate))")
                        return
                    } catch {
                        print("LockForConfiguration failed with error: \(error.localizedDescription)")
                        break
                    }
                }
            } else if frameRate >= frameRateRange.minFrameRate && frameRate <= frameRateRange.maxFrameRate {
                do {
                    try device.lockForConfiguration()
                    device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
                    device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
                    device.unlockForConfiguration()
                    print("setCameraFrameRate: \(Int(frameRate))")
                    return
                } catch {
                    print("LockForConfiguration failed with error: \(error.localizedDescription)")
                    break
                }
            }
        }
        print("Requested FPS is not supported by the device's activeFormat!")
    }
    
    
    // MARK: - Video Session
        
    func startSession() {
        if let videoSession = videoSession {
            if !videoSession.isRunning {
                videoSession.startRunning()
            }
        }
    }
            
    func stopSession() {
        if let videoSession = videoSession {
            if videoSession.isRunning {
                videoSession.stopRunning()
            }
        }
    }
    
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
        
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection)
    {
        detectRectangles(sampleBuffer: sampleBuffer)
    }
    
    
    // MARK: - Rectangle Detection
    
    func detectRectangles(sampleBuffer: CMSampleBuffer) {
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
                
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer,
                                                  key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
                                                  attachmentModeOut: nil)
        
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
                
        let request = VNDetectRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: requestHandlerOptions)
            
        try? handler.perform([request])
        
        guard let observations = request.results as? [VNRectangleObservation] else {
            return
        }
        
        if detectDigitFromFirstRectangle(observations, with: pixelBuffer) == false {
            DispatchQueue.main.async {
                self.imageView.image = nil
                self.digitLabel.stringValue = ""
                self.removeAllRectangleLayers()
                self.delegate?.detectedHandwrittenDigit(nil)
            }
        }
    }
    
    func detectDigitFromFirstRectangle(_ observations: [VNRectangleObservation], with imageBuffer: CVImageBuffer) -> Bool {
        if observations.count <= 0 { return false }
        
        guard let observation = observations.first else { return false }
        guard let image = cgImageWithPerspectiveCorrection(observation, from: imageBuffer) else { return false }
        guard let contoursImage = drawContours(cgImage: image) else { return false }
        
        DispatchQueue.main.async {
            self.imageView.image = nil
            self.digitLabel.stringValue = ""
            self.removeAllRectangleLayers()
            self.drawRectangle(observation)
            self.detectHandwrittenDigit(cgImage: contoursImage)
        }
        return true
    }
    
    func drawRectangle(_ observation: VNRectangleObservation) {
        let rectangleBounds = previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
        if rectangleBounds.width < 20 { return }
        
        let shape = CAShapeLayer()
        shape.frame = rectangleBounds
        shape.cornerRadius = 10
        shape.opacity = 0.75
        shape.borderColor = NSColor.red.cgColor
        shape.borderWidth = 6
        
        previewLayer.addSublayer(shape)
        rectangleLayers.append(shape)
    }
    
    func removeAllRectangleLayers() {
        if rectangleLayers.count <= 0 { return }
        
        for layer in rectangleLayers {
            layer.removeFromSuperlayer()
        }
        rectangleLayers.removeAll()
    }
    
    func cgImageWithPerspectiveCorrection(_ observation: VNRectangleObservation, from buffer: CVImageBuffer) -> CGImage? {
        var ciImage = CIImage(cvImageBuffer: buffer)
        
        let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
        let topRight = observation.topRight.scaled(to: ciImage.extent.size)
        let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
        let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)
        
        ciImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight),
        ])
        
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return cgImage
        }
        return nil
    }
    
    
    // MARK: - Contours Detection
    
    func drawContours(cgImage: CGImage) -> CGImage? {
        var image : CGImage?
        
        if isGaussianBlur {
            image = imageWithNoiseReduction(sourceImage: cgImage)
        } else {
            image = cgImage
        }
        
        if image == nil { return nil }
        
        let request = VNDetectContoursRequest()
        request.revision = VNDetectContourRequestRevision1
        request.contrastAdjustment = 1.0
        request.detectsDarkOnLight = true
        
        let handler = VNImageRequestHandler(cgImage: image!, options: [:])
        
        try? handler.perform([request])
        
        guard let observations = request.results as? [VNContoursObservation] else {
            return nil
        }
        //print("Contours: \(observations)")

        guard let observation = observations.first else { return nil }
        
        guard let contoursImage = contoursImage(size: CGSize(width: image!.width, height: image!.height),
                                                cgPath: observation.normalizedPath) else { return nil }
        
        guard let smallImage = resizedImage(cgImage: contoursImage, width: digitImageWidth) else {
            return nil
        }
        
        return croppedBorderImage(cgImage: smallImage, borderWidth: croppingBorderWidth)
    }
    
    func contoursImage(size: CGSize, cgPath: CGPath) -> CGImage? {
        let cgContext = CGContext(data: nil,
                                  width: Int(size.width),
                                  height: Int(size.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = cgContext else { return nil }
        
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        context.scaleBy(x: size.width, y: size.height)
        context.setLineWidth(contourWidth / CGFloat(size.width))
        context.setStrokeColor(NSColor.white.cgColor)
        
        context.addPath(cgPath)
        context.strokePath()
        
        return context.makeImage()
    }
    
    
    // MARK: - Handwritten Digit Detection
    
    func setupHandwrittenDigitDetectionModel() {
        //
        // MNISTClassifier.mlmodel:
        //   Classify a single handwritten digit (supports digits 0-9).
        //
        guard let modelURL = Bundle.main.url(forResource: "MNISTClassifier", withExtension: "mlmodelc") else {
            print(">> Model file is missing")
            return
        }
        
        do {
            let model = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let digitRecognition = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                if let results = request.results as? [VNClassificationObservation],
                   let observation = results.first,
                   observation.confidence >= Float(self.digitConfidence)
                {
                    //print(observation)
                    self.digitLabel.stringValue = "\(observation.identifier)"
                    self.delegate?.detectedHandwrittenDigit(Int(observation.identifier))
                }
            })
            self.digitRecognitionRequests = [digitRecognition]
            
        } catch {
            print("Model loading went wrong: \(error)")
        }
    }
    
    func detectHandwrittenDigit(cgImage: CGImage) {
        imageView.image = NSImage(cgImage: cgImage, size: .zero)
        
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try imageRequestHandler.perform(self.digitRecognitionRequests)
        } catch {
            print(error)
        }
    }
    
    
    // MARK: - Image Tools
    
    func croppedBorderImage(cgImage: CGImage, borderWidth: Int) -> CGImage? {
        if borderWidth <= 0 {
            return cgImage
        }
        if borderWidth >= Int(cgImage.width/2) {
            return cgImage
        }
        
        let x = borderWidth
        let y = borderWidth
        var width  = cgImage.width - (borderWidth*2)
        var height = cgImage.height - (borderWidth*2)
        
        if width < 0 {
            width = 0
        }
        if height < 0 {
            height = 0
        }
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
        return cgImage.cropping(to: rect)
    }
    
    func resizedImage(cgImage: CGImage, width: Int) -> CGImage? {
        let resizedWidth = width
        let resizedHeight = cgImage.height / (cgImage.width / width)
        
        let context = CGContext(data: nil,
                                width: resizedWidth,
                                height: resizedHeight,
                                bitsPerComponent: cgImage.bitsPerComponent,
                                bytesPerRow: cgImage.bytesPerRow,
                                space: cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: cgImage.bitmapInfo.rawValue)
        
        context?.interpolationQuality = .high
        context?.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: resizedWidth, height: resizedHeight)))

        return context?.makeImage()
    }
    
    func imageWithNoiseReduction(sourceImage: CGImage) -> CGImage? {
        let inputImage = CIImage(cgImage: sourceImage)
        
        let noiseReductionFilter = CIFilter.gaussianBlur()
        noiseReductionFilter.radius = 0.5
        noiseReductionFilter.inputImage = inputImage
        
        guard let outputImage = noiseReductionFilter.outputImage else { return nil }
        
        let context = CIContext()
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
    
    func imageWithDrawPath(sourceImage: CGImage, cgPath: CGPath) -> CGImage? {
        let size = CGSize(width: sourceImage.width, height: sourceImage.height)
        
        let cgContext = CGContext(data: nil,
                                  width: Int(size.width),
                                  height: Int(size.height),
                                  bitsPerComponent: sourceImage.bitsPerComponent,
                                  bytesPerRow: sourceImage.bytesPerRow,
                                  space: sourceImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: sourceImage.bitmapInfo.rawValue)
        
        guard let context = cgContext else { return nil }
        
        context.draw(sourceImage, in: CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height)))
        
        context.scaleBy(x: size.width, y: size.height)
        context.setLineWidth(8.0 / CGFloat(size.width))
        context.setStrokeColor(NSColor.red.cgColor)
        context.addPath(cgPath)
        context.strokePath()
        
        return context.makeImage()
    }
}


extension CGPoint {
   func scaled(to size: CGSize) -> CGPoint {
       return CGPoint(x: self.x * size.width,
                      y: self.y * size.height)
   }
}

