package com.example.flutter_rtmp_audio_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the RTMP Audio plugin
        flutterEngine.plugins.add(RtmpAudioPlugin())
    }
}
