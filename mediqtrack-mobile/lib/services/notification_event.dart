// lib/services/notification_event.dart
import 'package:flutter/foundation.dart';

class NotificationEventBus {
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void ping() {
    tick.value++;
  }
}
