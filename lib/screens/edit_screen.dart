import 'package:flutter/material.dart';

import '../alarm_service.dart';
import '../models.dart';

/// Thêm mới hoặc sửa một loại thuốc.
class EditScreen extends StatefulWidget {
  const EditScreen({super.key, this.medicine, required this.all});

  /// null = thêm thuốc mới.
  final Medicine? medicine;

  /// Toàn bộ danh sách thuốc hiện có.
  final List<Medicine> all;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _note;
  late List<int> _times;
  String? _nameError;
  String? _timeError;
  bool _saving = false;

  bool get _isNew => widget.medicine == null;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name = TextEditingController(text: m?.name ?? '');
    _dose = TextEditingController(text: m?.dose ?? '1 viên');
    _note = TextEditingController(text: m?.note ?? '');
    _times = [...?m?.times]..sort();
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: 'Chọn giờ uống',
      cancelText: 'Huỷ',
      confirmText: 'Chọn',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      if (!_times.contains(minutes)) _times.add(minutes);
      _times.sort();
      _timeError = null;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Nhập tên thuốc' : null;
      _timeError = _times.isEmpty ? 'Thêm ít nhất một giờ uống' : null;
    });
    if (_nameError != null || _timeError != null) return;

    setState(() => _saving = true);
    final list = [...widget.all];
    if (_isNew) {
      list.add(Medicine(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        dose: _dose.text.trim(),
        note: _note.text.trim(),
        times: _times,
      ));
    } else {
      final m = widget.medicine!;
      m
        ..name = name
        ..dose = _dose.text.trim()
        ..note = _note.text.trim()
        ..times = _times;
    }
    await MedicineStore.save(list);
    await AlarmService.sync(list);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá thuốc này?'),
        content: Text('Sẽ không còn chuông nhắc cho "${widget.medicine!.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final list = widget.all.where((m) => m.id != widget.medicine!.id).toList();
    await MedicineStore.save(list);
    await AlarmService.sync(list);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(fontSize: 20);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Thêm thuốc' : 'Sửa thuốc'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Xoá thuốc',
              icon: const Icon(Icons.delete_outline, size: 28),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            style: fieldStyle,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Tên thuốc',
              hintText: 'Metformin 500mg',
              border: const OutlineInputBorder(),
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dose,
            style: fieldStyle,
            decoration: const InputDecoration(
              labelText: 'Mỗi lần uống',
              hintText: '1 viên',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            style: fieldStyle,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (không bắt buộc)',
              hintText: 'Sau ăn',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Giờ uống mỗi ngày',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _times)
                InputChip(
                  label: Text(formatMinutes(t), style: const TextStyle(fontSize: 22)),
                  onDeleted: () => setState(() => _times.remove(t)),
                  deleteButtonTooltipMessage: 'Bỏ giờ này',
                ),
              ActionChip(
                avatar: const Icon(Icons.add),
                label: const Text('Thêm giờ', style: TextStyle(fontSize: 20)),
                onPressed: _addTime,
              ),
            ],
          ),
          if (_timeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _timeError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 32),
          SizedBox(
            height: 60,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Lưu', style: TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }
}
