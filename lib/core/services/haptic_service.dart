import 'package:flutter/services.dart';

class HapticService {
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }
  
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static void success() {
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }
}
