import 'package:flutter_test/flutter_test.dart';
import 'package:workgo_core/workgo_core.dart';

void main() {
  group('WorkGoTimeFormat Tests', () {
    test('converts railway time string to 12-hour AM/PM format', () {
      expect("08:00".to12HourTime(), equals("8:00 AM"));
      expect("20:00".to12HourTime(), equals("8:00 PM"));
      expect("14:30".to12HourTime(), equals("2:30 PM"));
      expect("00:15".to12HourTime(), equals("12:15 AM"));
      expect("12:00".to12HourTime(), equals("12:00 PM"));
      expect("23:59".to12HourTime(), equals("11:59 PM"));
      expect("09:05".to12HourTime(), equals("9:05 AM"));
    });

    test('preserves strings already in 12-hour format or invalid strings gracefully', () {
      expect("8:00 AM".to12HourTime(), equals("8:00 AM"));
      expect("5:30 PM".to12HourTime(), equals("5:30 PM"));
      expect("".to12HourTime(), equals(""));
      expect("not-a-time".to12HourTime(), equals("not-a-time"));
    });

    test('formats DateTime into 12-hour time and date strings', () {
      final dtMorning = DateTime(2026, 9, 3, 9, 30);
      expect(WorkGoTimeFormat.format12Hour(dtMorning), equals("9:30 AM"));
      expect(dtMorning.to12HourTime(), equals("9:30 AM"));

      final dtEvening = DateTime(2026, 9, 3, 19, 45);
      expect(WorkGoTimeFormat.format12Hour(dtEvening), equals("7:45 PM"));
      expect(dtEvening.to12HourTime(), equals("7:45 PM"));

      expect(dtEvening.to12HourDateTime(), equals("3 Sep · 7:45 PM"));
    });
  });
}
