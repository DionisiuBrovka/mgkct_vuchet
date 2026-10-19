import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:teaching_hours_server/src/statistics_xlsx.dart';

void main() {
  test(
    'Excel preserves long decimals, zero and absent plans, and escapes formulas',
    () {
      final category = {
        'planned': '0',
        'confirmed': '0.300000000000000000001',
        'submitted': '0.2',
        'remaining': '0',
        'excess': '0.0000000000000001',
      };
      final data = <String, dynamic>{
        'generatedAt': '2026-10-08T12:00:00Z',
        'filterLabels': {'Учебный год': '2026–2027'},
        'rows': [
          {
            'academicYear': 2026,
            'teacher': '=SUM(A1:A2)',
            'subject': 'Математика & логика',
            'group': 'ПР-21',
            'progress': {
              'main': category,
              'additional': {
                ...category,
                'planned': null,
                'confirmed': '7.25',
                'remaining': null,
                'excess': null,
              },
            },
          },
        ],
        'totals': {
          'main': {...category, 'missingPlans': 0},
          'additional': {
            ...category,
            'planned': '0',
            'confirmed': '7.25',
            'remaining': '0',
            'excess': '0',
            'missingPlans': 1,
          },
        },
      };
      final bytes = statisticsXlsx(data);
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet = utf8.decode(
        archive.findFile('xl/worksheets/sheet1.xml')!.content,
      );
      final additionalSheet = utf8.decode(
        archive.findFile('xl/worksheets/sheet2.xml')!.content,
      );
      final workbook = utf8.decode(
        archive.findFile('xl/workbook.xml')!.content,
      );
      final relationships = utf8.decode(
        archive.findFile('xl/_rels/workbook.xml.rels')!.content,
      );
      expect(workbook, contains('name="Основные часы"'));
      expect(workbook, contains('name="Дополнительные часы"'));
      expect(relationships, contains('Target="worksheets/sheet2.xml"'));
      expect(sheet, isNot(contains('7.25')));
      expect(additionalSheet, contains('<v>7.25</v>'));
      expect(additionalSheet, isNot(contains('0.300000000000000000001')));
      expect(sheet, contains('0.300000000000000000001'));
      expect(sheet, contains('0.0000000000000001'));
      expect(sheet, contains('<v>0</v>'));
      expect(additionalSheet, contains('Не задано'));
      expect(sheet, contains('Математика &amp; логика'));
      expect(sheet, contains('=SUM(A1:A2)'));
      expect(sheet, isNot(contains('<f>')));
      expect(sheet, contains('autoFilter'));
      expect(sheet, contains('state="frozen"'));
      expect(additionalSheet, contains('autoFilter'));
      expect(additionalSheet, contains('state="frozen"'));
      expect(additionalSheet, contains('Без плана: 1'));
      expect(additionalSheet, contains('Итого'));
      expect(archive.findFile('[Content_Types].xml'), isNotNull);
      final target = Platform.environment['STATISTICS_TEST_XLSX'];
      if (target != null) File(target).writeAsBytesSync(bytes);
    },
  );
}
