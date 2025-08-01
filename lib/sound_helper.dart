import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundHelper {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sound_enabled') ?? true;
  }

  static Future<void> playAddSound() async {
    if (await isSoundEnabled()) {
      try {
        await _audioPlayer.play(AssetSource('WhatsApp Audio 2025-07-17 at 8.34.16 PM.aac'));
      } catch (e) {
        print('Error playing add sound: $e');
      }
    }
  }

  static Future<void> playDeleteSound() async {
    if (await isSoundEnabled()) {
      try {
        await _audioPlayer.play(AssetSource('mixkit-censorship-beep-1082.wav'));
      } catch (e) {
        print('Error playing delete sound: $e');
      }
    }
  }
}