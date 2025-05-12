package com.example.flutter_rtmp_audio_app

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.pedro.rtmp.rtmp.RtmpClient
import com.pedro.rtmp.utils.ConnectCheckerRtmp
import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaCodecInfo
import java.nio.ByteBuffer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class RtmpAudioPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware, ConnectCheckerRtmp {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null

    private val REQUEST_RECORD_AUDIO_PERMISSION = 200
    
    // RTMP client for streaming
    private var rtmpClient: RtmpClient? = null
    private var isStreaming = false

    // Audio recording variables
    private var audioRecord: AudioRecord? = null
    private var minBufferSize = 0
    private var audioBuffer: ByteArray? = null
    private var sampleRate = 44100
    private var channelConfig = AudioFormat.CHANNEL_IN_MONO
    private var audioFormat = AudioFormat.ENCODING_PCM_16BIT
    private var bitrate = 128000
    
    // AAC encoder
    private var audioEncoder: MediaCodec? = null
    private var audioBufferInfo = MediaCodec.BufferInfo()
    private var presentationTimeUs: Long = 0
    
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.flutter_rtmp_audio_app/rtmp_audio")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.example.flutter_rtmp_audio_app/rtmp_audio_events")
        
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "startStreaming" -> {
                val url = call.argument<String>("url")
                sampleRate = call.argument<Int>("sampleRate") ?: 44100
                val channelCount = call.argument<Int>("channelCount") ?: 1
                bitrate = call.argument<Int>("bitrate") ?: 128000
                
                channelConfig = if (channelCount > 1) AudioFormat.CHANNEL_IN_STEREO else AudioFormat.CHANNEL_IN_MONO
                
                if (url != null) {
                    result.success(startStreaming(url))
                } else {
                    result.error("INVALID_ARGUMENT", "URL is required", null)
                }
            }
            "stopStreaming" -> {
                result.success(stopStreaming())
            }
            "checkMicrophonePermission" -> {
                result.success(checkMicrophonePermission())
            }
            "requestMicrophonePermission" -> {
                requestMicrophonePermission()
                result.success(true) // Just indicates we've requested the permission
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    private fun startStreaming(url: String): Boolean {
        if (isStreaming) {
            return true // Already streaming
        }
        
        if (!checkMicrophonePermission()) {
            updateState("failed")
            return false
        }
        
        try {
            updateState("connecting")
            
            // Initialize RTMP client if needed
            if (rtmpClient == null) {
                rtmpClient = RtmpClient(this)
            }
            
            // Setup buffer size based on sample rate
            minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            if (minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
                updateState("failed")
                return false
            }
            
            audioBuffer = ByteArray(minBufferSize)
            
            // Initialize AAC encoder
            initAudioEncoder()
            
            // Create AudioRecord instance
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                audioFormat,
                minBufferSize * 2
            )
            
            // Connect to RTMP server
            rtmpClient?.connect(url)
            presentationTimeUs = System.nanoTime() / 1000
            
            // Start audio recording and streaming
            audioRecord?.startRecording()
            
            // Process audio in a background thread
            executor.execute {
                while (isStreaming) {
                    try {
                        val read = audioRecord?.read(audioBuffer!!, 0, minBufferSize)
                        if (read != null && read > 0) {
                            encodePcmToAac(audioBuffer!!, read)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        mainHandler.post {
                            updateState("failed")
                            stopStreaming()
                        }
                        break
                    }
                }
            }
            
            isStreaming = true
            updateState("streaming")
            return true
            
        } catch (e: Exception) {
            e.printStackTrace()
            updateState("failed")
            stopStreaming()
            return false
        }
    }
    
    private fun stopStreaming(): Boolean {
        if (!isStreaming) {
            return true // Not streaming
        }
        
        try {
            isStreaming = false
            
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            
            releaseAudioEncoder()
            
            rtmpClient?.disconnect()
            
            updateState("disconnected")
            return true
            
        } catch (e: Exception) {
            e.printStackTrace()
            updateState("failed")
            return false
        }
    }
    
    private fun checkMicrophonePermission(): Boolean {
        if (activity == null) return false
        
        return ContextCompat.checkSelfPermission(
            activity!!,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun requestMicrophonePermission() {
        if (activity == null) return
        
        ActivityCompat.requestPermissions(
            activity!!,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            REQUEST_RECORD_AUDIO_PERMISSION
        )
    }
    
    private fun updateState(state: String) {
        mainHandler.post {
            val data = HashMap<String, Any>()
            data["state"] = state
            eventSink?.success(data)
        }
    }
    
    // Initialize the AAC encoder
    private fun initAudioEncoder() {
        try {
            // Create MediaFormat for AAC encoding
            val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, if (channelConfig == AudioFormat.CHANNEL_IN_STEREO) 2 else 1)
            format.setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, minBufferSize * 2)
            
            // Create and configure the encoder
            audioEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            audioEncoder?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            audioEncoder?.start()
        } catch (e: Exception) {
            e.printStackTrace()
            mainHandler.post {
                updateState("failed")
                stopStreaming()
            }
        }
    }
    
    // Release the AAC encoder
    private fun releaseAudioEncoder() {
        try {
            audioEncoder?.stop()
            audioEncoder?.release()
            audioEncoder = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    // Encode PCM audio data to AAC and send it through RTMP
    private fun encodePcmToAac(buffer: ByteArray, size: Int) {
        try {
            audioEncoder?.let { encoder ->
                // Get input buffer index with timeout
                val inputBufferIndex = encoder.dequeueInputBuffer(0)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = encoder.getInputBuffer(inputBufferIndex)
                    inputBuffer?.clear()
                    inputBuffer?.put(buffer, 0, size)
                    encoder.queueInputBuffer(inputBufferIndex, 0, size, System.nanoTime() / 1000, 0)
                }

                // Get encoded AAC data
                val bufferInfo = MediaCodec.BufferInfo()
                var outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 0)
                while (outputBufferIndex >= 0) {
                    val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)
                    
                    // Send AAC encoded data to RTMP server
                    if (outputBuffer != null && bufferInfo.size > 0 && bufferInfo.presentationTimeUs > 0) {
                        rtmpClient?.sendAudio(outputBuffer, bufferInfo)
                    }
                    
                    encoder.releaseOutputBuffer(outputBufferIndex, false)
                    outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, 0)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        stopStreaming()
        executor.shutdown()
    }
    
    // ConnectCheckerRtmp interface implementation
    override fun onConnectionStartedRtmp(rtmpUrl: String) {
        updateState("connecting")
    }

    override fun onConnectionSuccessRtmp() {
        updateState("streaming")
    }

    override fun onConnectionFailedRtmp(reason: String) {
        updateState("failed")
        stopStreaming()
    }

    override fun onNewBitrateRtmp(bitrate: Long) {
        // Optional: Handle bitrate changes
    }

    override fun onDisconnectRtmp() {
        updateState("disconnected")
    }

    override fun onAuthErrorRtmp() {
        updateState("failed")
        stopStreaming()
    }

    override fun onAuthSuccessRtmp() {
        // Authentication successful, waiting for connection
    }
}
