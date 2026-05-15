import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // ignore: unused_field
  static final AudioPlayer _player = AudioPlayer();

  static void playCardSlap() {
    _playSound('card_slap.mp3');
  }

  static void playTurnTick() {
    _playSound('turn_tick.mp3');
  }

  static void playRevealSting() {
    _playSound('reveal_sting.mp3');
  }

  static void playBluffAlarm() {
    _playSound('bluff_alarm.mp3');
  }

  static void playRoundWin() {
    _playSound('round_win.mp3');
  }

  static Future<void> _playSound(String asset) async {
    try {
      // Using placeholder logic:
      // await _player.play(AssetSource('sounds/$asset'));
    } catch (e) {
      // Ignore
    }
  }
}
