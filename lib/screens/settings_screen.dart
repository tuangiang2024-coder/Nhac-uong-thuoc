import 'package:flutter/material.dart';

import '../alarm_service.dart';

/// Kiểm tra quyền và thử chuông.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _notifOk;
  bool? _exactOk;
  String? _message;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final notif = await AlarmService.notificationsEnabled();
    final exact = await AlarmService.canScheduleExact();
    if (!mounted) return;
    setState(() {
      _notifOk = notif;
      _exactOk = exact;
    });
  }

  Future<void> _test() async {
    String msg;
    try {
      await AlarmService.scheduleTest(seconds: 10);
      msg = 'Chuông thử sẽ kêu sau 10 giây. Hãy tắt màn hình điện thoại và chờ.';
    } catch (_) {
      msg = 'Không đặt được chuông. Hãy bật quyền "Báo thức đúng giờ" bên dưới.';
    }
    if (!mounted) return;
    setState(() => _message = msg);
  }

  Widget _status(String label, bool? ok, VoidCallback onFix) {
    return ListTile(
      leading: Icon(
        ok == true ? Icons.check_circle : Icons.error_outline,
        color: ok == true ? Colors.green : Colors.orange,
        size: 32,
      ),
      title: Text(label, style: const TextStyle(fontSize: 18)),
      subtitle: Text(ok == true ? 'Đã bật' : 'Chưa bật'),
      trailing: ok == true
          ? null
          : TextButton(onPressed: onFix, child: const Text('Bật')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt chuông')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 64,
            child: FilledButton.icon(
              onPressed: _test,
              icon: const Icon(Icons.notifications_active, size: 28),
              label: const Text('Thử chuông (sau 10 giây)',
                  style: TextStyle(fontSize: 20)),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, style: const TextStyle(fontSize: 16)),
            ),
          const SizedBox(height: 24),
          const Text('Quyền cần có',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          _status('Hiện thông báo', _notifOk, () async {
            await AlarmService.requestNotificationPermission();
            await _check();
          }),
          _status('Báo thức đúng giờ', _exactOk, () async {
            await AlarmService.requestExactAlarmPermission();
            await _check();
          }),
          ListTile(
            leading: const Icon(Icons.fullscreen, size: 32),
            title: const Text('Hiện toàn màn hình khi khoá máy',
                style: TextStyle(fontSize: 18)),
            subtitle: const Text('Android 14 trở lên cần bật thủ công'),
            trailing: TextButton(
              onPressed: AlarmService.requestFullScreenPermission,
              child: const Text('Mở'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up, size: 32),
            title: const Text('Cài đặt thông báo của app',
                style: TextStyle(fontSize: 18)),
            subtitle: const Text('Kiểm tra âm thanh và cho phép hiện trên màn hình khoá'),
            trailing: TextButton(
              onPressed: AlarmService.openNotificationSettings,
              child: const Text('Mở'),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Để chuông không bị tắt ngầm, vào Cài đặt điện thoại → Ứng dụng → '
                'Nhắc uống thuốc → Pin, chọn "Không hạn chế". '
                'Trên Xiaomi, bật thêm "Tự khởi động". '
                'Âm lượng chuông theo âm lượng Báo thức của máy.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
