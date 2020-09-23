//
//  ViewController.swift
//  StreamaxiaDemo2
//
//  Created by Roland Tolnay on 9/21/16.
//  Copyright © 2016 Streamaxia. All rights reserved.
//

import UIKit
import StreamaxiaSDK
import AVFoundation

// Modify this to your desired stream name
// Playback will be available at play.streamaxia.com/<your-stream-name>
let kStreamaxiaStreamName: String = "ryan"

/// View controller that displays some basic UI for capturing and streaming
/// live video and audio media.
class ViewController: UIViewController {
    
    // MARK: - Private Constants -
    
    fileprivate let kStartButtonTag: NSInteger = 0
    
    fileprivate let kStopButtonTag: NSInteger = 1
    
    // MARK: - Private Properties -
    
    @IBOutlet weak var startButton: UIButton!
    
    @IBOutlet weak var leftLabel: UILabel!
    
    @IBOutlet weak var rightLabel: UILabel!
    
    @IBOutlet weak var infoLabel: UILabel!
    
    @IBOutlet weak var recorderView: UIView!
    
    @IBOutlet weak var overlayView: UIView!
    
    /// The recorder
    fileprivate var streamer = AXStreamer()
    fileprivate var streamSource = AXStreamSource()
    fileprivate let avAudioEngine = AVAudioEngine()
    var start: Double?
    
    /// The stream info
    fileprivate var streamInfo: AXStreamInfo!
    
    /// The recorder settings
    fileprivate var recorderSettings: AXRecorderSettings!
    let sendImage = UIImage(named: "AppIcon")?.cvPixelBuffer(size: CGSize(width: 1280, height: 720))
    var displayLink: CADisplayLink!

    
    // MARK: - View Lifecycle -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "StreamaxiaSDK Demo"
        
        self.setupUI()
        self.setupStreamaxiaSDK()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    // MARK: - Public methods -
    
    // MARK: - Actions -
    
    @IBAction func startButtonPressed(_ button: UIButton) {
        print("*** DEMO *** Recorder button pressed.")
        setupStreaming()
        setupAVAudioEngine()
        
        if (button.tag == self.kStartButtonTag) {
            print("*** DEMO *** START button pressed.")
            
          streamer.startStreaming { (success, error) in
            guard success else {
              print("ryan fail", error)
              return
            }
            self.streamSource.on = true
            self.startDisplayLink()
            self.startAudioEngine()
          }
        } else if (button.tag == self.kStopButtonTag) {
            print("*** DEMO *** STOP button pressed.")
            
            self.startButton.tag = self.kStartButtonTag
            self.startButton.setTitle("Start", for: .normal)
            self.streamer.stopStreaming()
            self.updateLabel(time: 0.0)
        }
    }
}

// MARK: - Private methods -

fileprivate extension ViewController {
  
  func setupAVAudioEngine() {
      let session = AVAudioSession.sharedInstance()
      do {
        try session.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.voiceChat, options: [.allowBluetooth, .allowAirPlay, .mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
        try session.setPreferredSampleRate(Double(48000))
        try avAudioEngine.inputNode.setVoiceProcessingEnabled(true)
        try avAudioEngine.outputNode.setVoiceProcessingEnabled(true)
      } catch {
        print("error with audio session")
      }
    
    let audioFormat = avAudioEngine.inputNode.outputFormat(forBus: 0)
    let mixer = AVAudioMixerNode()
    avAudioEngine.attach(mixer)
    avAudioEngine.connect(avAudioEngine.inputNode, to: mixer, format: audioFormat)
    
    let sinkNode = AVAudioSinkNode { (_, _, _) -> OSStatus in
      return noErr
    }
    
    avAudioEngine.attach(sinkNode)
    avAudioEngine.connect(mixer, to: sinkNode, format: audioFormat)
      
      mixer.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] (buffer, time) in
        var data = Data()
        let audioBufferList = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        for buffer in audioBufferList {
          guard let bufferData = buffer.mData?.assumingMemoryBound(to: UInt8.self) else {
            continue
          }
          data.append(bufferData, count: Int(buffer.mDataByteSize))
        }
        print("sending buffer")
        
        let timestamp: Double = Double(time.sampleTime) / time.sampleRate * 1000
        
        self?.streamer.sendAudioData(data, timestamp: UInt64(timestamp))
      }
    }
  
  func startAudioEngine() {
    do {
      avAudioEngine.prepare()
      try avAudioEngine.start()
    } catch _ {
      print("error starting avaudioengine")
    }
  }
  
  func startDisplayLink() {
    displayLink = CADisplayLink(target: self, selector: #selector(sendImageBuffer))
    displayLink.add(to: .main, forMode: .default)
    displayLink.preferredFramesPerSecond = 30
  }
    //#pragma mark - Private methods
    
  func defaultStreamInfo() -> AXStreamInfo {
        let info = AXStreamInfo.init()
        info.useSecureConnection = false
        
        info.customStreamURLString = "rtmp://rtmp.streamaxia.com/streamaxia/\(kStreamaxiaStreamName)"// "rtmp://a.rtmp.youtube.com/live2/<youtube streamkey>"

        info.username = ""
        info.password = ""
        
        return info
    }
    
    
  func setupStreamaxiaSDK() {
        let sdk = AXStreamaxiaSDK.sharedInstance()!
        
        // Alternatively, a custom bundle can be used to load the certificate:
        let bundleURL = Bundle.main.url(forResource: "demo-certificate", withExtension: "bundle")
        let bundle = Bundle.init(url: bundleURL!)
        
        sdk.setupSDK(with: bundle?.bundleURL) { (success, error) in
            sdk.debugPrintStatus()
            
            if (success) {
                DispatchQueue.main.async {
                    self.setupStreaming()
                }
            }
        }
    }
  
  @objc func sendImageBuffer() {
    let start = self.start ?? CACurrentMediaTime() * 1000
    self.start = start
    
    let timestamp = CACurrentMediaTime() * 1000
    guard let buffer = sendImage?.sampleBuffer(timestamp: timestamp - start) else {
      return
    }
    print("sending image")
    
    streamer.sendVideoBuffer(buffer)
  }
    
  func setupStreaming() {
      self.streamInfo = self.defaultStreamInfo()
      
      streamer.videoSettings.setResolution(.size1280x720, withError: nil)
      streamer.videoSettings.setSendingVideo(true, withError: nil)
      
      streamer.audioSettings.setChannelsNumber(2, withError: nil)
      streamer.audioSettings.setSampleRate(UInt(48000), withError: nil)
      streamer.audioSettings.setSendingAudio(true, withError: nil)
      streamer.delegate = self

      streamSource = streamer.addStreamSource(with: streamInfo)
      streamSource.delegate = self
    }
    
  func updateLabel(time: TimeInterval) {
        let t = Int(time)
        let s = t % 60
        let m = (t / 60) % 60
        let h = t / 3600
        
        let text = String.init(format: "T: %.2ld:%.2ld:%.2ld", Int(h), Int(m), Int(s))
        
        DispatchQueue.main.async {
            self.rightLabel.text = text
        }
    }
}

// MARK: - AXRecorderDelegate -

extension ViewController: AXStreamerDelegate {
  func streamer(_ streamer: AXStreamer!, didChange state: AXStreamerState) {
    print("*** DEMO *** Recorder State Changed to: \(state)")
    
    var string = "N/A"
    
    switch state {
    case .stopped:
      string = "[Stopped]"
      string = "[Recording]"
    case .starting:
      string = "[Starting...]"
    case .stopping:
      string = "[Stopping...]"
    case .streaming:
      string = "[Streaming...]"
    default:
      string = "[Unknown state]"
    }
    
    DispatchQueue.main.async {
      self.leftLabel.text = string
    }
  }
  
  func streamer(_ streamer: AXStreamer!, didReceive warning: AXWarning!) {
    print("ryan warning")
    
  }
  
  func streamer(_ streamer: AXStreamer!, didReceiveError error: AXError!) {
    print("ryan error")
  }
}

extension ViewController: AXStreamSourceDelegate {
  func streamSourceDidConnect(_ streamSource: AXStreamSource!) {
    print("ryan did connect")
  }
  
  func streamSourceDidCloseConnection(_ streamSource: AXStreamSource!) {
    print("ryan did close")
  }
  
  func streamSourceDidDisconnect(_ streamSource: AXStreamSource!) {
    print("ryan did disc")
  }
  
  func streamSource(_ streamSource: AXStreamSource!, didFailConnectingWithError error: AXError!) {
    print("ryan did fail")
  }
  
}

// MARK: - UI Setup -

fileprivate extension ViewController {
    
    private func infoFont() -> UIFont? {
        return UIFont.init(name: "AvenirNextCondensed-UltraLight", size: 14.0)
    }
    
    private func labelFont() -> UIFont? {
        return UIFont.init(name: "AvenirNextCondensed-Regular", size: 16.0)
    }
    
    private func buttonFont() -> UIFont? {
        return UIFont.init(name: "AvenirNextCondensed-Medium", size: 20.0)
    }
    
  func setupUI() {
        self.setupMain()
        self.setupStartButton()
        self.setupLeftLabel()
        self.setupRightLabel()
        self.setupInfoLabel()
    }
    
    private func setupMain() {
        self.recorderView.backgroundColor = UIColor.white
        self.overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        self.view.backgroundColor = UIColor.lightGray
    }
    
    private func setupStartButton() {
        let button: UIButton = self.startButton!
        
        button.layer.cornerRadius = self.startButton.frame.size.height * 0.5
        button.backgroundColor = UIColor.black
        button.tintColor = UIColor.white
        button.tag = self.kStartButtonTag
        button.titleLabel?.font = self.buttonFont()
        button.setTitle("Start", for: .normal)
    }
    
    private func setupLeftLabel() {
        let label = self.leftLabel!
        
        label.font = self.labelFont()
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.text = "[N/A]"
        label.textColor = UIColor.white
    }
    
    private func setupRightLabel() {
        let label = self.rightLabel!
        
        label.font = self.labelFont()
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.text = "T: 00:00:00"
        label.textColor = UIColor.white
    }
    
    private func setupInfoLabel() {
        let label = self.infoLabel!
        
        label.font = self.infoFont()
        label.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        label.text = ""
        label.textColor = UIColor.white
    }
}


extension UIImage {
  func cvPixelBuffer(size: CGSize) -> CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard (status == kCVReturnSuccess) else {
      return nil
    }

    CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

    context?.translateBy(x: 0, y: size.height)
    context?.scaleBy(x: 1.0, y: -1.0)

    UIGraphicsPushContext(context!)
    draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

    return pixelBuffer
  }
}

extension CVPixelBuffer {
  func sampleBuffer(timestamp: Double) -> CMSampleBuffer? {
    var newSampleBuffer: CMSampleBuffer? = nil
    var timingInfo = CMSampleTimingInfo()
    timingInfo.presentationTimeStamp = CMTime(value: Int64(timestamp), timescale: 1000)
    timingInfo.duration = CMTime(seconds: 1, preferredTimescale: 30)
    timingInfo.decodeTimeStamp = CMTime.invalid
    var videoInfo: CMVideoFormatDescription? = nil
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: self,
                                                 formatDescriptionOut: &videoInfo)
    CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                       imageBuffer: self,
                                       dataReady: true,
                                       makeDataReadyCallback: nil,
                                       refcon: nil,
                                       formatDescription: videoInfo!,
                                       sampleTiming: &timingInfo,
                                       sampleBufferOut: &newSampleBuffer)
    return newSampleBuffer
  }
}
