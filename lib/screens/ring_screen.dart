import 'package:flutter/material.dart';

import '../alarm_service.dart';
import '../models.dart';

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

  bool get _isTest => widget.payload == AlarmService.testPayload;
  int? get _minutes => int.tryParse(widget.payload);

  @override
  void initState() {
    super.initState();
    MedicineStore.load().then((list) {
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    });
  }

  Future<void> _taken() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (_isTest) {
      await AlarmService.cancelTest();
    } else if (_minutes != null) {
      // Đọc lại danh sách từ máy: nếu bấm quá nhanh khi _all chưa tải xong,
      // chuông của giờ này sẽ bị huỷ mà không được đặt lại cho ngày mai.
      await AlarmService.markTaken(_minutes!, await MedicineStore.load());
    }
    if (!mounted) return;
    Navigator.of(context).pop();
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
              const SizedBox(height: 16),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = [
      if (med.dose.trim().isNotEmpty) med.dose.trim(),
      if (med.note.trim().isNotEmpty) med.note.trim(),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.medication, size: 40, color: scheme.onPrimaryContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
