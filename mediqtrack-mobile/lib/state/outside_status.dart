import 'package:flutter/foundation.dart';

class OutsideStatus {
  OutsideStatus._();
  static final OutsideStatus instance = OutsideStatus._();

  final ValueNotifier<bool> isOutside = ValueNotifier<bool>(false);
  final ValueNotifier<int> secondsLeft = ValueNotifier<int>(60);

  void show(int seconds) {
    if (seconds < 0) seconds = 0;
    isOutside.value = true;
    secondsLeft.value = seconds;
  }

  void updateSeconds(int seconds) {
    if (seconds < 0) seconds = 0;
    secondsLeft.value = seconds;
  }

  void hide(int resetSeconds) {
    isOutside.value = false;
    secondsLeft.value = resetSeconds;
  }
}
