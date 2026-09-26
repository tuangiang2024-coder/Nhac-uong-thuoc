import 'package:flutter_test/flutter_test.dart';
import 'package:nhac_uong_thuoc/models.dart';

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
}
