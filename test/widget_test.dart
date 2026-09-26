import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nhac_uong_thuoc/models.dart';
import 'package:nhac_uong_thuoc/voice.dart';

void main() {
  test('Hiển thị giờ dạng HH:mm', () {
    expect(formatMinutes(0), '00:00');
    expect(formatMinutes(7 * 60 + 5), '07:05');
    expect(formatMinutes(20 * 60), '20:00');
  });

  test('Gom thuốc theo giờ uống', () {
    final a = Medicine(id: 'a', name: 'A', dose: '1 viên', note: '', times: [1200, 420]);
    final b = Medicine(id: 'b', name: 'B', dose: '', note: 'sau ăn', times: [1200]);
    final slots = groupByTime([a, b]);
    expect(slots.keys.toList(), [420, 1200]);
    expect(slots[1200]!.map((m) => m.id), ['a', 'b']);
    expect(b.summary, 'B – sau ăn');
  });

  test('Lưu và đọc lại thuốc có ảnh', () {
    final a = Medicine(id: 'a', name: 'A', dose: '1 viên', note: '', times: [420],
        photo: 'thuoc_1.jpg');
    final back = Medicine.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
    expect(back.photo, 'thuoc_1.jpg');
    expect(back.times, [420]);
    expect(Medicine.fromJson({'id': 'b'}).photo, '');
  });

  test('Soạn lời đọc nhắc uống thuốc', () {
    final a = Medicine(id: 'a', name: 'Metformin 500mg', dose: '1 viên', note: 'sau ăn',
        times: [1200], guide: 'Uống với nhiều nước');
    final b = Medicine(id: 'b', name: 'Amlodipin 5mg', dose: '1 viên', note: '', times: [1200]);
    expect(spokenText('Metformin 500mg, 5 ml'), 'Metformin 500 mi li gam, 5 mi li lít');
    expect(spokenText('Uống 2 gói, 10g'), 'Uống 2 gói, 10 gam');
    expect(partOfDay(7 * 60), 'buổi sáng');
    expect(partOfDay(20 * 60), 'buổi tối');
    final one = reminderSpeech(1200, [a], 'Mẹ');
    expect(one, startsWith('Mẹ ơi, đến giờ uống thuốc buổi tối rồi ạ.'));
    expect(one, contains('Metformin 500 mi li gam, 1 viên, sau ăn. Uống với nhiều nước.'));
    final two = reminderSpeech(1200, [a, b], '');
    expect(two, startsWith('Đến giờ uống thuốc buổi tối'));
    expect(two, contains('Có 2 loại thuốc. Thứ nhất:'));
    expect(two, contains('Thứ hai: Amlodipin 5 mi li gam, 1 viên.'));
  });
}
