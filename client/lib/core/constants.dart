import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static String get apiUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    return configured.isNotEmpty
        ? configured
        : kIsWeb
            ? Uri.base.origin
            : 'http://127.0.0.1:8080';
  }

  // Учебный год: сентябрь–июль (11 месяцев)
  static const months = [
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
  ];

  // Месяцы осенне-зимнего семестра принадлежат году начала учебного года,
  // остальные — следующему календарному году.
  static const _autumnWinter = {
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  };

  static int yearForMonth(String month, int academicYearStart) =>
      _autumnWinter.contains(month) ? academicYearStart : academicYearStart + 1;

  // Обратная функция: по месяцу и календарному году → год начала учебного года
  static int academicYearStart(String month, int calendarYear) =>
      _autumnWinter.contains(month) ? calendarYear : calendarYear - 1;

  // Год начала текущего учебного года (сентябрь = новый год)
  static int currentAcademicYear() {
    final now = DateTime.now();
    return now.month >= 9 ? now.year : now.year - 1;
  }
}
