import 'package:flutter/material.dart';

import '../alarm_service.dart';
import '../models.dart';
import '../photos.dart';
import '../voice.dart';

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
  late final TextEditingController _guide;
  late List<int> _times;
  String? _nameError;
  String? _timeError;
  bool _saving = false;

  /// Ảnh đang chọn (tên file), ảnh ban đầu, và các ảnh mới chụp trong lần sửa này.
  String _photo = '';
  String _originalPhoto = '';
  final List<String> _newPhotos = [];
  bool _saved = false;

  bool get _isNew => widget.medicine == null;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name = TextEditingController(text: m?.name ?? '');
    _dose = TextEditingController(text: m?.dose ?? '1 viên');
    _note = TextEditingController(text: m?.note ?? '');
    _guide = TextEditingController(text: m?.guide ?? '');
    _times = [...?m?.times]..sort();
    _photo = m?.photo ?? '';
    _originalPhoto = _photo;
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _note.dispose();
    _guide.dispose();
    Voice.stop();
    // Thoát mà không lưu: xoá các ảnh vừa chụp.
    if (!_saved) {
      for (final p in _newPhotos) {
        PhotoStore.delete(p);
      }
    }
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
        guide: _guide.text.trim(),
        photo: _photo,
      ));
    } else {
      final m = widget.medicine!;
      m
        ..name = name
        ..dose = _dose.text.trim()
        ..note = _note.text.trim()
        ..guide = _guide.text.trim()
        ..photo = _photo
        ..times = _times;
    }
    _saved = true;
    await MedicineStore.save(list);
    // Dọn các ảnh không còn dùng (sau khi đã lưu danh sách mới).
    for (final p in [..._newPhotos, _originalPhoto]) {
      if (p.isNotEmpty && p != _photo) await PhotoStore.delete(p);
    }
    await AlarmService.sync(list);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _pickPhoto({required bool fromCamera}) async {
    try {
      final name = await PhotoStore.pick(fromCamera: fromCamera);
      if (name == null) return;
      if (!mounted) {
        await PhotoStore.delete(name);
        return;
      }
      setState(() {
        _newPhotos.add(name);
        _photo = name;
      });
    } catch (e) {
      debugPrint('Lỗi lấy ảnh: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không mở được máy ảnh. Hãy cho phép app dùng máy ảnh/ảnh trong Cài đặt.'),
      ));
    }
  }

  Widget _photoSection() {
    final file = PhotoStore.fileFor(_photo);
    final buttons = Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(fromCamera: true),
            icon: const Icon(Icons.photo_camera),
            label: Text(file == null ? 'Chụp ảnh' : 'Chụp lại'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(fromCamera: false),
            icon: const Icon(Icons.photo_library),
            label: const Text('Chọn ảnh'),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ảnh viên thuốc / vỉ thuốc',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (file != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  file,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filledTonal(
                  tooltip: 'Bỏ ảnh',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _photo = ''),
                ),
              ),
            ],
          )
        else
          const Text(
            'Chụp rõ viên thuốc hoặc vỉ thuốc để lúc chuông kêu dễ nhận ra.',
            style: TextStyle(fontSize: 15),
          ),
        const SizedBox(height: 8),
        buttons,
      ],
    );
  }

  /// Đọc thử lời nhắc cho riêng thuốc này.
  Future<void> _preview() async {
    final settings = await VoiceSettings.load();
    final draft = Medicine(
      id: 'preview',
      name: _name.text.trim().isEmpty ? 'Thuốc' : _name.text.trim(),
      dose: _dose.text.trim(),
      note: _note.text.trim(),
      times: _times,
      guide: _guide.text.trim(),
    );
    final minutes = _times.isEmpty ? 7 * 60 : _times.first;
    final ok = await Voice.vietnameseReady() &&
        await Voice.speak(
      reminderSpeech(minutes, [draft], settings.callName),
      rate: settings.rate,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Máy chưa có giọng đọc tiếng Việt. Xem mục Cài đặt chuông.'),
      ));
    }
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
    _saved = false; // để dispose() xoá các ảnh mới chụp
    final list = widget.all.where((m) => m.id != widget.medicine!.id).toList();
    await MedicineStore.save(list);
    await PhotoStore.delete(_originalPhoto);
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
          _photoSection(),
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
          const SizedBox(height: 16),
          TextField(
            controller: _guide,
            style: fieldStyle,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Hướng dẫn cách uống (máy sẽ đọc to)',
              hintText: 'Uống với một cốc nước đầy, không nhai viên thuốc',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _preview,
              icon: const Icon(Icons.volume_up),
              label: const Text('Nghe thử', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 16),
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
