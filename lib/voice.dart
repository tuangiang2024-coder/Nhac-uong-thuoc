import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Cài đặt giọng đọc, lưu trong máy.
class VoiceSettings {
  VoiceSettings({
    required this.enabled,
    required this.callName,
    required this.rate,
  });

  /// Có đọc nhắc bằng giọng nói không.
  bool enabled;

  /// Cách gọi người uống thuốc, ví dụ "Mẹ", "Bố", "Bà". Để trống thì không gọi tên.
  String callName;

  /// Tốc độ đọc: 1.0 là bình thường, nhỏ hơn là chậm hơn.
  double rate;

  static const _kEnabled = 'voice_enabled';
  static const _kCallName = 'voice_call_name';
  static const _kRate = 'voice_rate';

  static Future<VoiceSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return VoiceSettings(
      enabled: p.getBool(_kEnabled) ?? true,
      callName: p.getString(_kCallName) ?? '',
      rate: p.getDouble(_kRate) ?? 0.85,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, enabled);
    await p.setString(_kCallName, callName.trim());
    await p.setDouble(_kRate, rate);
  }
}

/// Gọi bộ đọc giọng nói tiếng Việt của Android (viết trong MainActivity.kt).
class Voice {
  Voice._();

  static const MethodChannel _channel = MethodChannel('nhac_uong_thuoc/giong_noi');

  static Future<bool> speak(String text, {double rate = 0.85}) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'speak',
        {'text': text, 'rate': rate},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('Không đọc được: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }

  /// Máy đã có giọng đọc tiếng Việt chưa.
  static Future<bool> vietnameseReady() async {
    try {
      // Có máy khởi tạo bộ đọc rất lâu hoặc không bao giờ trả lời: đừng chờ mãi.
      final status = await _channel
          .invokeMethod<int>('vietnameseStatus')
          .timeout(const Duration(seconds: 8));
      return (status ?? -3) >= 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openTtsSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openTtsSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}

// ---------------- Soạn lời đọc ----------------

/// "buổi sáng", "buổi trưa"... theo giờ trong ngày.
String partOfDay(int minutes) {
  final h = minutes ~/ 60;
  if (h < 4) return 'ban đêm';
  if (h < 11) return 'buổi sáng';
  if (h < 14) return 'buổi trưa';
  if (h < 18) return 'buổi chiều';
  return 'buổi tối';
}

/// Đổi chữ viết tắt sang cách đọc cho máy đọc tự nhiên hơn.
String spokenText(String text) {
  var s = text;
  final units = <String, String>{
    'mg': 'mi li gam',
    'mcg': 'mi crô gam',
    'ml': 'mi li lít',
    'g': 'gam',
    'IU': 'đơn vị',
  };
  units.forEach((unit, spoken) {
    s = s.replaceAllMapped(
      // Không dùng \b: trong RegExp của Dart, \b coi chữ có dấu (ó, ừ...) là
      // "không phải chữ", nên "2 gói" sẽ bị đọc thành "2 gamói".
      RegExp('(\\d)\\s*$unit(?![\\p{L}\\p{N}_])', unicode: true),
      (m) => '${m[1]} $spoken',
    );
  });
  return s;
}

const _ordinals = ['Thứ nhất', 'Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm',
  'Thứ sáu', 'Thứ bảy', 'Thứ tám', 'Thứ chín', 'Thứ mười'];

/// Lời đọc cho một loại thuốc: tên, liều, ghi chú, hướng dẫn.
String medicineSpeech(Medicine m) {
  final parts = <String>[
    m.name.trim(),
    if (m.dose.trim().isNotEmpty) m.dose.trim(),
    if (m.note.trim().isNotEmpty) m.note.trim(),
  ];
  var s = '${parts.join(', ')}.';
  if (m.guide.trim().isNotEmpty) {
    final g = m.guide.trim();
    s += ' ${g.endsWith('.') ? g : '$g.'}';
  }
  return spokenText(s);
}

/// Toàn bộ lời nhắc khi đến giờ uống thuốc.
String reminderSpeech(int minutes, List<Medicine> meds, String callName) {
  final name = callName.trim();
  final b = StringBuffer();
  b.write(name.isEmpty ? '' : '$name ơi, ');
  b.write('đến giờ uống thuốc ${partOfDay(minutes)} rồi ạ. ');
  if (meds.length == 1) {
    b.write('Uống thuốc ${medicineSpeech(meds.first)} ');
  } else {
    b.write('Có ${meds.length} loại thuốc. ');
    for (var i = 0; i < meds.length; i++) {
      final label = i < _ordinals.length ? _ordinals[i] : 'Tiếp theo';
      b.write('$label: ${medicineSpeech(meds[i])} ');
    }
  }
  b.write('Uống xong thì bấm nút Đã uống màu xanh nhé.');
  final text = b.toString();
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
