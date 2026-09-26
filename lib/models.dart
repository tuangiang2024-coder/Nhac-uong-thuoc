import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Một loại thuốc và các giờ uống trong ngày.
class Medicine {
  Medicine({
    required this.id,
    required this.name,
    required this.dose,
    required this.note,
    required this.times,
    this.guide = '',
    this.photo = '',
  });

  final String id;
  String name;

  /// Liều mỗi lần uống, ví dụ "1 viên".
  String dose;

  /// Ghi chú ngắn, ví dụ "sau ăn". Có thể để trống.
  String note;

  /// Hướng dẫn cách uống, máy sẽ đọc to khi đến giờ.
  /// Ví dụ: "Uống với một cốc nước đầy, không nhai viên thuốc".
  String guide;

  /// Tên file ảnh viên/vỉ thuốc (xem PhotoStore). Để trống nếu chưa có ảnh.
  String photo;

  /// Các giờ uống, tính bằng số phút kể từ 0 giờ (ví dụ 20:00 = 1200).
  List<int> times;

  /// Mô tả ngắn gọn: "Metformin 500mg – 1 viên, sau ăn".
  String get summary {
    final parts = <String>[
      if (dose.trim().isNotEmpty) dose.trim(),
      if (note.trim().isNotEmpty) note.trim(),
    ];
    return parts.isEmpty ? name : '$name – ${parts.join(', ')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'note': note,
        'times': times,
        'guide': guide,
        'photo': photo,
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        dose: json['dose'] as String? ?? '',
        note: json['note'] as String? ?? '',
        times: (json['times'] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        guide: json['guide'] as String? ?? '',
        photo: json['photo'] as String? ?? '',
      );
}

/// Hiển thị số phút trong ngày dưới dạng "HH:mm".
String formatMinutes(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Lưu danh sách thuốc ngay trong điện thoại.
class MedicineStore {
  static const _key = 'medicines_v1';

  static Future<List<Medicine>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Medicine> medicines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(medicines.map((m) => m.toJson()).toList()),
    );
  }
}

/// Gom thuốc theo từng giờ uống: {1200: [thuốc A, thuốc B], ...}, sắp theo giờ.
Map<int, List<Medicine>> groupByTime(List<Medicine> medicines) {
  final map = <int, List<Medicine>>{};
  for (final med in medicines) {
    for (final t in med.times.toSet()) {
      map.putIfAbsent(t, () => []).add(med);
    }
  }
  final keys = map.keys.toList()..sort();
  return {for (final k in keys) k: map[k]!};
}
