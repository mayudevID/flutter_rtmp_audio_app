# Flutter RTMP Audio Streaming App

A Flutter application for RTMP audio streaming using native implementations:
- Android: rtmp-rtsp-stream-client-java (Kotlin)
- iOS: HaishinKit

## Features

- Audio-only RTMP streaming
- Native implementations for better performance
- Configurable streaming parameters (sample rate, channel count, bitrate)
- Streaming status indicators
- Permission handling

## Implementation Details

### Android Native Implementation

This app uses the [rtmp-rtsp-stream-client-java](https://github.com/pedroSG94/rtmp-rtsp-stream-client-java) library for Android to handle RTMP streaming. The implementation:

- Uses AudioRecord for capturing audio
- Streams audio data in a background thread
- Handles permissions and stream state management

### iOS Native Implementation

For iOS, the app uses [HaishinKit](https://github.com/shogo4405/HaishinKit.swift), which is a powerful streaming library for iOS. The implementation:

- Uses AVAudioSession for audio recording
- Configures RTMP connection and streaming
- Manages audio stream settings and permissions

### Flutter Integration

The app uses Flutter's method channels and event channels to communicate between the Flutter UI and native code:

- Method channels for commands (start streaming, stop streaming, etc.)
- Event channels for state updates (connected, streaming, failed, etc.)

## Getting Started

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. For iOS, run `pod install` in the iOS directory
4. Run the app with `flutter run`

## Usage

1. Enter a valid RTMP URL in the format `rtmp://server/app/stream`
2. Tap "Start Streaming" to begin streaming audio
3. The status indicator will show the current streaming state
4. Tap "Stop Streaming" to end the stream

## Configuration

You can modify these parameters in the app:
- Sample rate (default: 44100 Hz)
- Channel count (default: Mono)
- Bitrate (default: 128 kbps)
