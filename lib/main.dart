import 'package:flutter/material.dart';
import 'models/stream_settings.dart';
import 'services/rtmp_audio_service.dart';
import 'platform_interface/rtmp_audio_platform_interface.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTMP Audio Streamer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const StreamingPage(),
    );
  }
}

class StreamingPage extends StatefulWidget {
  const StreamingPage({super.key});

  @override
  State<StreamingPage> createState() => _StreamingPageState();
}

class _StreamingPageState extends State<StreamingPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController(
    text: 'rtmp://',
  );
  final RtmpAudioService _rtmpService = RtmpAudioService();

  StreamState _currentState = StreamState.disconnected;
  String _errorMessage = '';
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();

    // Listen for stream state changes
    _rtmpService.onStateChanged.listen((state) {
      setState(() {
        _currentState = state;
        _isStreaming = state == StreamState.streaming;

        if (state == StreamState.failed) {
          _errorMessage = 'Streaming failed';
        } else {
          _errorMessage = '';
        }
      });
    });

    // Check microphone permission
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    bool hasPermission = await _rtmpService.checkMicrophonePermission();
    if (!hasPermission) {
      // Request permission if not granted
      await _rtmpService.requestMicrophonePermission();
    }
  }

  Future<void> _startStreaming() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final settings = StreamSettings(
      url: _urlController.text,
      sampleRate: 44100,
      channelCount: 1,
      bitrate: 128000,
    );

    setState(() {
      _currentState = StreamState.connecting;
    });

    final result = await _rtmpService.startStreaming(settings);
    if (!result && mounted) {
      setState(() {
        _currentState = StreamState.failed;
        _errorMessage = 'Failed to start streaming';
      });
    }
  }

  Future<void> _stopStreaming() async {
    final result = await _rtmpService.stopStreaming();
    if (!result && mounted) {
      setState(() {
        _errorMessage = 'Failed to stop streaming';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _rtmpService.dispose();
    super.dispose();
  }

  String _getStateText() {
    switch (_currentState) {
      case StreamState.connecting:
        return 'Connecting...';
      case StreamState.streaming:
        return 'Streaming';
      case StreamState.failed:
        return 'Failed';
      case StreamState.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RTMP Audio Streamer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'RTMP URL',
                  hintText: 'rtmp://server/app/stream',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a RTMP URL';
                  }
                  if (!value.startsWith('rtmp://')) {
                    return 'URL must start with rtmp://';
                  }
                  return null;
                },
                enabled: !_isStreaming,
              ),
              const SizedBox(height: 20),
              Text(
                'Status: ${_getStateText()}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isStreaming ? _stopStreaming : _startStreaming,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isStreaming ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _isStreaming ? 'Stop Streaming' : 'Start Streaming',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
