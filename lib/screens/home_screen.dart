import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../alarm_service.dart';
import '../models.dart';
import 'edit_screen.dart';
import 'ring_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.launchResponse});

  /// Có giá trị khi app được mở do chuông báo.
  final NotificationResponse? launchResponse;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Medicine> _medicines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AlarmService.requestNotificationPermission();
      final launch = widget.launchResponse;
      if (launch != null &&
          launch.actionId != AlarmService.takenActionId &&
          launch.payload != null &&
          mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RingScreen(payload: launch.payload!)),
        );
        _reload();
      }
    });
  }

  Future<void> _reload() async {
    final list = await MedicineStore.load();
    if (!mounted) return;
    setState(() {
      _medicines = list;
      _loading = false;
    });
  }

  Future<void> _openEditor([Medicine? med]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditScreen(medicine: med, all: _medicines),
      ),
    );
    if (changed == true) await _reload();
  }

  /// Giờ uống tiếp theo tính từ bây giờ.
  int? _nextSlot(Map<int, List<Medicine>> slots) {
    if (slots.isEmpty) return null;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    for (final t in slots.keys) {
      if (t > nowMin) return t;
    }
    return slots.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slots = groupByTime(_medicines);
    final next = _nextSlot(slots);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhắc uống thuốc'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt chuông',
            icon: const Icon(Icons.settings, size: 30),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add, size: 30),
        label: const Text('Thêm thuốc', style: TextStyle(fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _medicines.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    if (next != null)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lần uống tiếp theo',
                              style: TextStyle(
                                fontSize: 16,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              formatMinutes(next),
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              '${slots[next]!.length} loại thuốc',
                              style: TextStyle(
                                fontSize: 16,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Lịch uống mỗi ngày',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in slots.entries)
                      _SlotCard(
                        minutes: entry.key,
                        meds: entry.value,
                        onTapMedicine: _openEditor,
                      ),
                  ],
                ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.minutes,
    required this.meds,
    required this.onTapMedicine,
  });

  final int minutes;
  final List<Medicine> meds;
  final void Function(Medicine) onTapMedicine;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.alarm, size: 26),
                  const SizedBox(width: 8),
                  Text(
                    formatMinutes(minutes),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (final med in meds)
              ListTile(
                leading: const Icon(Icons.medication, size: 30),
                title: Text(
                  med.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (med.dose.trim().isNotEmpty) med.dose.trim(),
                    if (med.note.trim().isNotEmpty) med.note.trim(),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => onTapMedicine(med),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 72),
            SizedBox(height: 12),
            Text(
              'Chưa có thuốc nào',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Bấm "Thêm thuốc" để nhập tên thuốc và giờ uống. '
              'Đến giờ, điện thoại sẽ đổ chuông.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
