import 'package:flutter/material.dart';

import '../alarm_service.dart';
import '../voice.dart';

/// Kiểm tra quyền và thử chuông.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool? _notifOk;
  bool? _viOk;
  VoiceSettings? _voice;
  final _callName = TextEditingController();
  bool? _exactOk;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VoiceSettings.load().then((v) {
      if (!mounted) return;
      _callName.text = v.callName;
      setState(() => _voice = v);
    });
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callName.dispose();
    Voice.stop();
    super.dispose();
  }

  /// Quay lại từ màn Cài đặt của máy thì kiểm tra lại quyền và giọng đọc.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _saveVoice() async {
    final v = _voice;
    if (v == null) return;
    v.callName = _callName.text;
    await v.save();
  }

  Future<void> _previewVoice() async {
    await _saveVoice();
    final v = _voice;
    if (v == null) return;
    final name = v.callName.trim();
    final greeting = name.isEmpty ? 'Xin chào.' : '$name ơi, xin chào.';
    final ok = await Voice.vietnameseReady() &&
        await Voice.speak(
      spokenText('$greeting Đây là giọng đọc nhắc uống thuốc. '
          'Ví dụ: Metformin 500mg, 1 viên, uống sau ăn.'),
      rate: v.rate,
    );
    if (!ok && mounted) {
      setState(() => _viOk = false);
    }
  }

  Future<void> _check() async {
    final notif = await AlarmService.notificationsEnabled();
    final exact = await AlarmService.canScheduleExact();
    final vi = await Voice.vietnameseReady();
    if (!mounted) return;
    setState(() {
      _notifOk = notif;
      _exactOk = exact;
      _viOk = vi;
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

  List<Widget> _voiceSection() {
    final v = _voice;
    if (v == null) return const [];
    return [
      const Text('Giọng đọc',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Đọc nhắc bằng giọng nói', style: TextStyle(fontSize: 18)),
        subtitle: const Text('Đến giờ, máy đọc tên thuốc và cách uống'),
        value: v.enabled,
        onChanged: (on) {
          setState(() => v.enabled = on);
          _saveVoice();
        },
      ),
      if (v.enabled) ...[
        _status('Giọng tiếng Việt trên máy', _viOk, () async {
          final opened = await Voice.openTtsSettings();
          if (!opened && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Không mở được. Vào Cài đặt → Hỗ trợ tiếp cận → Chuyển văn bản thành giọng nói.'),
            ));
          }
        }),
        if (_viOk == false)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Bấm "Bật", chọn bộ đọc "Google" (Dịch vụ lời nói của Google), '
              'đặt ngôn ngữ Tiếng Việt và tải giọng Tiếng Việt về máy. '
              'Nếu chưa có, cài "Dịch vụ lời nói của Google" từ CH Play.',
              style: TextStyle(fontSize: 15),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _callName,
          style: const TextStyle(fontSize: 20),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Gọi người uống thuốc là',
            hintText: 'Mẹ',
            helperText: 'Máy sẽ đọc: "Mẹ ơi, đến giờ uống thuốc…". Để trống nếu không cần.',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _saveVoice(),
        ),
        const SizedBox(height: 16),
        const Text('Tốc độ đọc', style: TextStyle(fontSize: 18)),
        Row(
          children: [
            const Text('Chậm'),
            Expanded(
              child: Slider(
                min: 0.5,
                max: 1.2,
                divisions: 7,
                value: v.rate.clamp(0.5, 1.2),
                onChanged: (r) => setState(() => v.rate = r),
                onChangeEnd: (_) => _saveVoice(),
              ),
            ),
            const Text('Nhanh'),
          ],
        ),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _previewVoice,
            icon: const Icon(Icons.volume_up, size: 26),
            label: const Text('Nghe thử giọng đọc', style: TextStyle(fontSize: 18)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Giọng đọc theo âm lượng Báo thức của máy.',
            style: TextStyle(fontSize: 15),
          ),
        ),
      ],
    ];
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
          ..._voiceSection(),
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
