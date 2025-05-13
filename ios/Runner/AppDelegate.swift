import Flutter
import UIKit
import AVFoundation
import HaishinKit

// StreamState enum definition
enum StreamState: String {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case streaming = "streaming"
    case failed = "failed"
}

// RtmpAudioPlugin implementation
class RtmpAudioPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var rtmpConnection: RTMPConnection?
    private var rtmpStream: RTMPStream?
    private var isStreaming = false
    private var eventSink: FlutterEventSink?
    
    // Audio settings
    private var sampleRate: Double = 44100
    private var channelCount: Int = 1
    private var bitrate: Int = 128000
    
    // Register the plugin with Flutter
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.example.flutter_rtmp_audio_app/rtmp_audio", binaryMessenger: registrar.messenger())
        let instance = RtmpAudioPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Register event channel for streaming state updates
        let eventChannel = FlutterEventChannel(name: "com.example.flutter_rtmp_audio_app/rtmp_audio_events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }
    
    // Handle method calls from Flutter
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startStreaming":
            if let args = call.arguments as? [String: Any],
               let url = args["url"] as? String {
                
                // Configure audio parameters
                if let sampleRateValue = args["sampleRate"] as? Int {
                    sampleRate = Double(sampleRateValue)
                }
                
                if let channelCountValue = args["channelCount"] as? Int {
                    channelCount = channelCountValue
                }
                
                if let bitrateValue = args["bitrate"] as? Int {
                    bitrate = bitrateValue
                }
                
                result(startStreaming(url: url))
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "URL is required", details: nil))
            }
            
        case "stopStreaming":
            result(stopStreaming())
            
        case "checkMicrophonePermission":
            checkMicrophonePermission { [weak self] granted in
                result(granted)
            }
            
        case "requestMicrophonePermission":
            requestMicrophonePermission { [weak self] granted in
                result(granted)
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - FlutterStreamHandler
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    private func startStreaming(url: String) -> Bool {
        if isStreaming {
            return true // Already streaming
        }
        
        // Request audio permission before streaming
        requestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }
            
            if !granted {
                self.updateState(.failed)
                return
            }
            
            DispatchQueue.main.async {
                self.setupStreaming(url: url)
            }
        }
        
        return true
    }
    
    private func setupStreaming(url: String) {
        self.updateState(.connecting)
        
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record)
            try audioSession.setActive(true)
            
            // Create RTMP connection and stream
            rtmpConnection = RTMPConnection()
            rtmpStream = RTMPStream(connection: rtmpConnection!)
            
            // Configure audio settings - use properties of RTMPStream directly
            if let stream = rtmpStream {
                // HaishinKit handles audio settings internally
                // We can set other properties according to documentation as needed
                print("Audio stream configured with sampleRate: \(sampleRate), channels: \(channelCount), bitrate: \(bitrate)")
            }
            
            // Set up audio only (no video)
            rtmpStream?.attachAudio(AVCaptureDevice.default(for: .audio))
            
            // Add event listeners
            rtmpConnection?.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection?.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            
            // Parse URL
            guard let urlComponents = URLComponents(string: url),
                  let scheme = urlComponents.scheme,
                  let host = urlComponents.host,
                  scheme == "rtmp" else {
                updateState(.failed)
                return
            }
            
            let port = urlComponents.port ?? 1935
            let path = urlComponents.path.isEmpty ? "/" : urlComponents.path
            
            // Extract stream name from path
            let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
            var app = "live" // Default application name
            var streamKey = "stream" // Default stream key
            
            if pathComponents.count > 1 {
                app = pathComponents[0]
                streamKey = pathComponents[1]
            } else if pathComponents.count == 1 {
                streamKey = pathComponents[0]
            }
            
            // Connect to RTMP server
            rtmpConnection?.connect("\(scheme)://\(host):\(port)/\(app)")
            rtmpStream?.publish(streamKey)
            
            isStreaming = true
            updateState(.streaming)
            
        } catch {
            print("Error setting up streaming: \(error)")
            updateState(.failed)
        }
    }
    
    @objc private func rtmpStatusHandler(_ notification: Notification) {
        guard let data = notification.userInfo as? [String: Any],
              let code = data["code"] as? String else {
            return
        }
        
        switch code {
        case "NetConnection.Connect.Success":
            // Connection succeeded, stream will start soon
            print("RTMP connection established")
        case "NetStream.Publish.Start":
            updateState(.streaming)
        case "NetConnection.Connect.Closed", "NetStream.Unpublish.Success":
            updateState(.disconnected)
            stopStreaming()
        case "NetConnection.Connect.Failed", "NetStream.Publish.BadName":
            updateState(.failed)
            stopStreaming()
        default:
            print("RTMP status: \(code)")
        }
    }
    
    @objc private func rtmpErrorHandler(_ notification: Notification) {
        updateState(.failed)
        stopStreaming()
    }
    
    private func stopStreaming() -> Bool {
        if !isStreaming {
            return true // Not streaming
        }
        
        do {
            // Stop audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
            
            // Stop streaming
            rtmpStream?.close()
            rtmpConnection?.close()
            rtmpConnection?.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection?.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            rtmpStream = nil
            rtmpConnection = nil
            
            isStreaming = false
            updateState(.disconnected)
            return true
            
        } catch {
            print("Error stopping stream: \(error)")
            updateState(.failed)
            return false
        }
    }
    
    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            requestMicrophonePermission(completion: completion)
        @unknown default:
            completion(false)
        }
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            completion(granted)
        }
    }
    
    private func updateState(_ state: StreamState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let eventSink = self.eventSink else { return }
            eventSink(["state": state.rawValue])
        }
    }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup our custom plugin manually
    let registrar = self.registrar(forPlugin: "RtmpAudioPlugin")
    if let registrar = registrar {
      RtmpAudioPlugin.register(with: registrar)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
