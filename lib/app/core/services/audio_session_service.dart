import 'package:audio_session/audio_session.dart';

/// Service to configure audio session for background playback of voice messages.
/// This allows voice messages to continue playing when the app is in background
/// or when the user switches to another app.
class AudioSessionService {
  AudioSessionService._();
  static final AudioSessionService instance = AudioSessionService._();

  bool _isInitialized = false;

  /// Initialize the audio session for background playback.
  /// Should be called once during app startup.
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      final session = await AudioSession.instance;
      
      // Configure for playback (voice messages)
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
          flags: AndroidAudioFlags.none,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      
      // Activate the session
      await session.setActive(true);
      
      _isInitialized = true;
      print('✅ Audio session configured for background playback');
    } catch (e) {
      print('⚠️ Error configuring audio session: $e');
    }
  }

  /// Activate audio session before playing
  Future<void> activate() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e) {
      print('⚠️ Error activating audio session: $e');
    }
  }

  /// Deactivate audio session when done playing
  Future<void> deactivate() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      print('⚠️ Error deactivating audio session: $e');
    }
  }
}
