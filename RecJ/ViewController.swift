//
//  ViewController.swift
//  SafeCycle
//
//  Created by Yuki Omae on 2022/07/19.
//

import UIKit
import AVFoundation
import Vision
import Foundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    
    // Start flag
    var logging = false
    var uuid = ""
    
    @IBOutlet var previewView: UIView!
    @IBOutlet weak var videoView: UIView!
    
    @IBOutlet weak var loggingSwitch: UISwitch!
    @IBAction func logging(_ sender: UISwitch) {
        if sender.isOn {
            self.logging = true
            self.uuid = UUID().uuidString
            writingToFile(text: "timestamp,lat,lon,ax,ay,az,speed,detect,confidence\n")
        }
        else{
            self.logging = false
            let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(self.uuid).appendingPathExtension("csv")
            var req = URLRequest(url: URL(string: "https://webhook.site/574128a2-6db9-46d9-a491-abdadedb11af")!)
            req.httpMethod = "POST"
            URLSession.shared.uploadTask(with: req, fromFile: path) { (data, res, err) in
                //                 print(data, res, err)
            }.resume()
            let loadingView = UIView(frame: UIScreen.main.bounds)
            loadingView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
            
            let activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            activityIndicator.center = loadingView.center
            activityIndicator.color = UIColor.white
            activityIndicator.style = UIActivityIndicatorView.Style.large
            activityIndicator.hidesWhenStopped = true
            activityIndicator.startAnimating()
            loadingView.addSubview(activityIndicator)
            
            UIApplication.shared.windows.filter{$0.isKeyWindow}.first?.addSubview(loadingView)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
                loadingView.removeFromSuperview()
                guard let url = URL(string: "https://www.kyoto-u.ac.jp/ja") else { return }
                UIApplication.shared.open(url)
            })
            print("false")
        }
    }
    
    
    
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // to be implemented in the subclass
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //        self.view.bringSubviewToFront(controllerView)
        //        self.view.sendSubviewToBack(videoView)
        self.view.sendSubviewToBack(videoView)
        setupAVCapture()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        //        session.sessionPreset = .vga640x480 // Model image size is smaller.
        session.sessionPreset = .photo
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = videoView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
    }
    
    func startCaptureSession() {
        session.startRunning()
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
    
    func writingToFile(text: String){
        guard let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("フォルダURL取得エラー")
        }
        let fileURL = dirURL.appendingPathComponent(self.uuid + ".csv")
        guard let stream = OutputStream(url: fileURL, append: true) else {
            fatalError("ストリームエラー")
        }
        stream.open()
        defer {
            stream.close()
        }
        guard let data = text.data(using: .utf8) else {
            fatalError("データエラー")
        }
        let result = data.withUnsafeBytes {
            stream.write($0, maxLength: data.count)
        }
    }
}

