import 'package:hijri/hijri_calendar.dart';

void main() {
  HijriCalendar.setLocal('ar');
  var h = HijriCalendar.fromDate(DateTime.now());
  print('Current: ${h.toFormat("DD MM YYYY")}');
  print('hDay: ${h.hDay}');
  print('lengthOfMonth: ${h.lengthOfMonth}'); // Checking if this property exists
  print('getDaysInMonth: ${h.getDaysInMonth(h.hYear, h.hMonth)}'); // Checking method
}
