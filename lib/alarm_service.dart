import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Chạy khi bấm nút "Đã uống" ngay trên thông báo (app không cần mở).
/// Thông báo đã được tắt sẵn, nên ở đây không cần làm gì thêm.
@pragma('vm:entry-point')
void onNotificationActionInBackground(NotificationResponse response) {}

/// Quản lý chuông báo: mỗi giờ uống thuốc là một chuông lặp lại hằng ngày.
///
/// Mã chuông = số phút trong ngày (0..1439), ví dụ 20:00 có mã 1200.
class AlarmService {
  AlarmService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int testAlarmId = 99999;
  static const String testPayload = 'test';
  static const String takenActionId = 'da_uong';

  static const String _channelId = 'nhac_uong_thuoc_chuong_v1';
  static const String _channelName = 'Chuông uống thuốc';

  /// Cờ FLAG_INSISTENT của Android: chuông kêu lặp lại đến khi được tắt.
  static const int _insistentFlag = 4;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init({
    required void Function(NotificationResponse) onTap,
  }) async {
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notify'),
      ),
      onDidReceiveNotificationResponse: onTap,
      onDidReceiveBackgroundNotificationResponse:
          onNotificationActionInBackground,
    );
  }

  /// Nếu app được mở do chuông báo, trả về thông tin chuông đó.
  static Future<NotificationResponse?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse;
  }

  // ---------------- Quyền ----------------

  static Future<bool> requestNotificationPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  static Future<bool> requestExactAlarmPermission() async =>
      await _android?.requestExactAlarmsPermission() ?? true;

  static Future<bool> requestFullScreenPermission() async =>
      await _android?.requestFullScreenIntentPermission() ?? true;

  static Future<bool> notificationsEnabled() async =>
      await _android?.areNotificationsEnabled() ?? true;

  static Future<bool> canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  static Future<void> openNotificationSettings() async {
    await _plugin.openAppNotificationSettings();
  }

  // ---------------- Lên lịch chuông ----------------

  static NotificationDetails _details(String body) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Chuông báo đến giờ uống thuốc',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: const RawResourceAndroidNotificationSound('chuong'),
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 500, 800, 500, 800]),
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        // Tự tắt sau 30 phút nếu không có ai bấm.
        timeoutAfter: 30 * 60 * 1000,
        additionalFlags: Int32List.fromList([_insistentFlag]),
        styleInformation: BigTextStyleInformation(body),
        actions: const [
          AndroidNotificationAction(
            takenActionId,
            'ĐÃ UỐNG',
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      ),
    );
  }

  /// Lần tới của giờ [minutes] tính từ bây giờ (hôm nay nếu chưa qua, không thì ngày mai).
  static tz.TZDateTime _nextInstance(int minutes) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  static String _bodyFor(List<Medicine> meds) =>
      meds.map((m) => '• ${m.summary}').join('\n');

  static Future<void> _scheduleSlot(int minutes, List<Medicine> meds) async {
    // Nếu máy chưa cho phép "Báo thức đúng giờ", thư viện sẽ báo lỗi.
    // Bắt lỗi ở đây để app không bị treo/tắt khi mở; màn Cài đặt sẽ báo "Chưa bật".
    try {
      await _plugin.zonedSchedule(
        id: minutes,
        title: 'Đến giờ uống thuốc ${formatMinutes(minutes)}',
        body: _bodyFor(meds),
        scheduledDate: _nextInstance(minutes),
        notificationDetails: _details(_bodyFor(meds)),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: minutes.toString(),
      );
    } catch (e) {
      debugPrint('Không đặt được chuông ${formatMinutes(minutes)}: $e');
    }
  }

  /// Đồng bộ chuông với danh sách thuốc hiện tại.
  /// Không tắt chuông đang kêu, chỉ thêm/sửa/xoá lịch.
  static Future<void> sync(List<Medicine> medicines) async {
    final slots = groupByTime(medicines);
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id != testAlarmId && !slots.containsKey(p.id)) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      debugPrint('Không đọc được danh sách chuông: $e');
    }
    for (final entry in slots.entries) {
      await _scheduleSlot(entry.key, entry.value);
    }
  }

  /// Tắt chuông đang kêu của giờ [minutes] và giữ lịch cho ngày mai.
  static Future<void> markTaken(int minutes, List<Medicine> medicines) async {
    await _plugin.cancel(id: minutes);
    final meds = groupByTime(medicines)[minutes];
    if (meds != null && meds.isNotEmpty) {
      await _scheduleSlot(minutes, meds);
    }
  }

  /// Chuông thử: kêu sau [seconds] giây.
  static Future<void> scheduleTest({int seconds = 10}) async {
    const body = 'Nếu bạn nghe thấy chuông này là app đã hoạt động.';
    await _plugin.zonedSchedule(
      id: testAlarmId,
      title: 'Chuông thử',
      body: body,
      scheduledDate:
          tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
      notificationDetails: _details(body),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: testPayload,
    );
  }

  static Future<void> cancelTest() => _plugin.cancel(id: testAlarmId);
}
