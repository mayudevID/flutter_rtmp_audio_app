import 'dart:async';
import '../platform_interface/rtmp_audio_platform_interface.dart';
import '../models/stream_settings.dart';

class RtmpAudioService {
  final RtmpAudioPlatformInterface _platformInterface =
      RtmpAudioPlatformInterface();

  // Stream controller for stream state changes
  StreamSubscription? _stateSubscription;
  final StreamController<StreamState> _stateController =
      StreamController<StreamState>.broadcast();

  // Get stream of state changes
  Stream<StreamState> get onStateChanged => _stateController.stream;

  RtmpAudioService() {
    _stateSubscription = _platformInterface.onStateChanged.listen((state) {
      _stateController.add(state);
    });
  }

  // Start streaming with the given settings
  Future<bool> startStreaming(StreamSettings settings) async {
    return _platformInterface.startStreaming(settings);
  }

  // Stop streaming
  Future<bool> stopStreaming() async {
    return _platformInterface.stopStreaming();
  }

  // Check for microphone permission
  Future<bool> checkMicrophonePermission() async {
    return _platformInterface.checkMicrophonePermission();
  }

  // Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    return _platformInterface.requestMicrophonePermission();
  }

  // Mute audio during streaming
  Future<bool> muteAudio() async {
    return _platformInterface.muteAudio();
  }

  // Unmute audio during streaming
  Future<bool> unmuteAudio() async {
    return _platformInterface.unmuteAudio();
  }

  // Dispose resources
  void dispose() {
    _stateSubscription?.cancel();
    _stateController.close();
  }
}
