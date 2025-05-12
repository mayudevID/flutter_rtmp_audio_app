import 'dart:async';
import 'package:flutter/services.dart';
import '../models/stream_settings.dart';

enum StreamState {
  disconnected,
  connecting,
  streaming,
  failed,
}

class RtmpAudioPlatformInterface {
  static const MethodChannel _channel =
      MethodChannel('com.example.flutter_rtmp_audio_app/rtmp_audio');
  static const EventChannel _eventChannel =
      EventChannel('com.example.flutter_rtmp_audio_app/rtmp_audio_events');

  static Stream<StreamState>? _stateStream;

  // Get streaming state events
  Stream<StreamState> get onStateChanged {
    _stateStream ??=
        _eventChannel.receiveBroadcastStream().map((dynamic event) {
      final String state = event['state'] as String;
      switch (state) {
        case 'disconnected':
          return StreamState.disconnected;
        case 'connecting':
          return StreamState.connecting;
        case 'streaming':
          return StreamState.streaming;
        case 'failed':
          return StreamState.failed;
        default:
          throw ArgumentError('Unknown stream state: $state');
      }
    });
    return _stateStream!;
  }

  // Start streaming
  Future<bool> startStreaming(StreamSettings settings) async {
    try {
      final bool result =
          await _channel.invokeMethod('startStreaming', settings.toMap());
      return result;
    } on PlatformException catch (e) {
      print('Error starting stream: ${e.message}');
      return false;
    }
  }

  // Stop streaming
  Future<bool> stopStreaming() async {
    try {
      final bool result = await _channel.invokeMethod('stopStreaming');
      return result;
    } on PlatformException catch (e) {
      print('Error stopping stream: ${e.message}');
      return false;
    }
  }

  // Check if microphone permissions are granted
  Future<bool> checkMicrophonePermission() async {
    try {
      final bool result =
          await _channel.invokeMethod('checkMicrophonePermission');
      return result;
    } on PlatformException catch (e) {
      print('Error checking microphone permission: ${e.message}');
      return false;
    }
  }

  // Request microphone permissions
  Future<bool> requestMicrophonePermission() async {
    try {
      final bool result =
          await _channel.invokeMethod('requestMicrophonePermission');
      return result;
    } on PlatformException catch (e) {
      print('Error requesting microphone permission: ${e.message}');
      return false;
    }
  }
}
