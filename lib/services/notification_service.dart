import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<void> init() async {
    if (!isSupported || _ready) return;
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (bindingName.contains('TestWidgetsFlutterBinding')) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final local = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(local.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const windows = WindowsInitializationSettings(
        appName: 'أذكار',
        appUserModelId: 'com.athkar.athkar',
        guid: 'd8c4e2a1-7b39-4f06-9e51-3a2c8d6b0f14',
      );
      await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: ios,
          macOS: ios,
          windows: windows,
        ),
      );
      await _requestPermissions();
      _ready = true;
    } catch (error) {
      debugPrint('Notifications unavailable: $error');
    }
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> reschedulePrayers({
    required DailyPrayers today,
    required DailyPrayers tomorrow,
    required AppSettings settings,
  }) async {
    if (!_ready) return;
    for (var id = 100; id < 130; id++) {
      await _plugin.cancel(id);
    }
    if (!settings.adhanEnabled) return;

    var nextId = 100;
    for (final day in [today, tomorrow]) {
      for (final slot in day.salahSlots) {
        if (!settings.isAdhanOn(slot.id)) continue;
        if (!slot.time.isAfter(DateTime.now())) continue;
        await _schedule(
          id: nextId++,
          title: 'حان وقت صلاة ${slot.arabicName}',
          body: 'بارك الله فيك. افتح التطبيق للأذان أو الأذكار.',
          when: slot.time,
        );
      }
    }
  }

  Future<void> rescheduleAthkarReminders(
    List<AthkarCollection> collections,
  ) async {
    if (!_ready) return;
    for (var id = 200; id < 400; id++) {
      await _plugin.cancel(id);
    }
    for (final collection in collections) {
      final reminder = collection.reminder;
      if (reminder == null || !reminder.enabled) continue;
      final id = 200 + (collection.id.hashCode.abs() % 180);
      final now = tz.TZDateTime.now(tz.local);
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        reminder.hour,
        reminder.minute,
      );
      if (!when.isAfter(now)) {
        when = when.add(const Duration(days: 1));
      }
      await _schedule(
        id: id,
        title: collection.name,
        body: 'تذكير بالأذكار. افتح القائمة وأكمل وردك.',
        when: when.toLocal(),
        daily: true,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    bool daily = false,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'athkar_prayer',
        'الصلاة والأذكار',
        channelDescription: 'تنبيهات مواقيت الصلاة وتذكير الأذكار',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
      windows: const WindowsNotificationDetails(),
    );

    final scheduled = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      );
    }
  }
}
