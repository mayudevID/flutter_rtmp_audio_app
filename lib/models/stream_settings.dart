class StreamSettings {
  final String url;
  final int sampleRate;
  final int channelCount;
  final int bitrate;

  StreamSettings({
    required this.url,
    this.sampleRate = 44100,
    this.channelCount = 1,
    this.bitrate = 128000,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'sampleRate': sampleRate,
      'channelCount': channelCount,
      'bitrate': bitrate,
    };
  }
}
