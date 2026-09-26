import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../alarm_service.dart';
import '../models.dart';
import '../photos.dart';
import '../voice.dart';

/// Màn hình hiện ra khi đến giờ uống thuốc.
class RingScreen extends StatefulWidget {
  const RingScreen({super.key, required this.payload});

  /// Số phút trong ngày (ví dụ "1200") hoặc "test" cho chuông thử.
  final String payload;

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  List<Medicine> _all = [];
  bool _loading = true;
  bool _busy = false;

  VoiceSettings? _voice;
  bool _voiceOk = false;
  Timer? _repeatTimer;
  int _timesSpoken = 0;

  /// Đọc lại lời nhắc mỗi phút, tối đa 30 lần (khoảng 30 phút, bằng thời gian chuông kêu) nếu chưa ai bấm.
  static const _repeatEvery = Duration(seconds: 60);
  static const _maxRepeats = 30;

  bool get _isTest => widget.payload == AlarmService.testPayload;
  int? get _minutes => int.tryParse(widget.payload);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final list = await MedicineStore.load();
    final voice = await VoiceSettings.load();
    final voiceOk = voice.enabled && await Voice.vietnameseReady();
    if (!mounted) return;
    setState(() {
      _all = list;
      _voice = voice;
      _voiceOk = voiceOk;
      _loading = false;
    });
    if (!voiceOk) return; // Không có giọng đọc: để chuông tiếp tục kêu.

    // Chỉ tắt chuông khi đã đọc được, nếu không thì để chuông tiếp tục kêu.
    final spoke = await _speak();
    if (!mounted || _busy) return;
    if (!spoke) {
      setState(() => _voiceOk = false);
      return;
    }
    // Tắt tiếng chuông để nghe rõ giọng đọc (lịch ngày mai vẫn giữ nguyên).
    await _silenceAlarm();
    // Người dùng có thể đã bấm "Đã uống" trong lúc chờ: không hẹn đọc lại nữa.
    if (!mounted || _busy) return;
    _repeatTimer = Timer.periodic(_repeatEvery, (t) {
      if (!mounted || _busy || _timesSpoken >= _maxRepeats) {
        t.cancel();
        return;
      }
      _speak();
    });
  }

  Future<void> _silenceAlarm() async {
    if (_isTest) {
      await AlarmService.cancelTest();
    } else if (_minutes != null) {
      await AlarmService.markTaken(_minutes!, await MedicineStore.load());
    }
  }

  String _speech() {
    final name = _voice?.callName ?? '';
    if (_isTest) {
      return spokenText('${name.isEmpty ? '' : '$name ơi, '}'
          'đây là chuông thử. Giọng đọc đã hoạt động. '
          'Bấm nút Đã uống màu xanh để tắt.');
    }
    final minutes = _minutes;
    if (minutes == null) return '';
    final meds = groupByTime(_all)[minutes] ?? const <Medicine>[];
    if (meds.isEmpty) return '';
    return reminderSpeech(minutes, meds, name);
  }

  Future<bool> _speak() async {
    final text = _speech();
    if (text.isEmpty || !mounted) return false;
    _timesSpoken++;
    return Voice.speak(text, rate: _voice?.rate ?? 0.85);
  }

  Future<void> _replay() async {
    _timesSpoken = 0; // Bấm nghe lại thì tính lại từ đầu.
    await _speak();
  }

  Future<void> _taken() async {
    if (_busy) return;
    setState(() => _busy = true);
    _repeatTimer?.cancel();
    await Voice.stop();
    // Đọc lại danh sách từ máy: nếu bấm quá nhanh khi _all chưa tải xong,
    // chuông của giờ này sẽ bị huỷ mà không được đặt lại cho ngày mai.
    await _silenceAlarm();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    Voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meds = _minutes == null
        ? const <Medicine>[]
        : (groupByTime(_all)[_minutes!] ?? const <Medicine>[]);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.alarm, size: 56, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                _isTest ? 'Chuông thử' : 'Đến giờ uống thuốc',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              ),
              if (_minutes != null)
                Text(
                  formatMinutes(_minutes!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _isTest
                        ? const Center(
                            child: Text(
                              'App đã hoạt động. Bấm "Đã uống" để tắt chuông.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20),
                            ),
                          )
                        : meds.isEmpty
                            ? const Center(
                                child: Text(
                                  'Không còn thuốc nào ở giờ này.',
                                  style: TextStyle(fontSize: 20),
                                ),
                              )
                            : ListView.separated(
                                itemCount: meds.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) => _MedicineTile(med: meds[i]),
                              ),
              ),
              const SizedBox(height: 12),
              if (_voiceOk)
                SizedBox(
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _replay,
                    icon: const Icon(Icons.volume_up, size: 30),
                    label: const Text('Nghe lại', style: TextStyle(fontSize: 24)),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _busy ? null : _taken,
                  icon: const Icon(Icons.check_circle_outline, size: 36),
                  label: const Text(
                    'Đã uống',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  const _MedicineTile({required this.med});

  final Medicine med;

  /// Bấm vào ảnh để xem to, có thể phóng to bằng hai ngón tay.
  void _showPhoto(BuildContext context, File file) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = PhotoStore.fileFor(med.photo);
    final detail = [
      if (med.dose.trim().isNotEmpty) med.dose.trim(),
      if (med.note.trim().isNotEmpty) med.note.trim(),
    ].join(' · ');
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          med.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: scheme.onPrimaryContainer,
          ),
        ),
        if (detail.isNotEmpty)
          Text(
            detail,
            style: TextStyle(
              fontSize: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
        if (med.guide.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              med.guide.trim(),
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null) ...[
            GestureDetector(
              onTap: () => _showPhoto(context, photo),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  photo,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (photo == null) ...[
                Icon(Icons.medication, size: 40, color: scheme.onPrimaryContainer),
                const SizedBox(width: 14),
              ],
              Expanded(child: text),
            ],
          ),
        ],
      ),
    );
  }
}
