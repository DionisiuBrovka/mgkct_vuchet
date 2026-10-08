import 'dart:convert';
import 'package:archive/archive.dart';

String _xml(Object? value) => const HtmlEscape(
  HtmlEscapeMode.element,
).convert('$value'.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ''));

/// Cell types are explicit: names cannot become formulas; long decimals stay exact.
List<int> statisticsXlsx(Map<String, dynamic> data) {
  final archive = Archive();
  void file(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  final body = StringBuffer();
  var rowNumber = 0;
  void row(
    List<Object?> values, {
    int style = 0,
    bool numbers = false,
    int height = 24,
  }) {
    rowNumber++;
    body.write('<row r="$rowNumber" ht="$height" customHeight="1">');
    for (var column = 0; column < values.length; column++) {
      final value = values[column];
      final ref = '${String.fromCharCode(65 + column)}$rowNumber';
      final text = value == null ? 'Не задано' : '$value';
      // Excel has 15 significant digits. No conversion through binary floating point.
      final numeric =
          numbers &&
          column >= 5 &&
          RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]*[1-9])?$').hasMatch(text) &&
          text.replaceAll('.', '').replaceFirst(RegExp(r'^0+'), '').length <=
              15 &&
          text.length < 100 &&
          (text.split('.').length == 1 || text.split('.').last.length <= 15);
      final cellStyle = value == null
          ? 4
          : numeric
          ? 3
          : style;
      body.write(
        numeric
            ? '<c r="$ref" s="$cellStyle"><v>$text</v></c>'
            : '<c r="$ref" s="$cellStyle" t="inlineStr"><is><t xml:space="preserve">${_xml(text)}</t></is></c>',
      );
    }
    body.write('</row>');
  }

  row(['Учебная нагрузка — план и выполнение'], style: 1, height: 32);
  row(['Сформировано: ${data['generatedAt']} (UTC)']);
  row(['Остаток — по подтверждённым часам. Черновики и замены не включены.']);
  row([
    'Длинные числа сохранены текстом без округления. Пустой план не равен нулю.',
  ]);
  final filters = data['filterLabels'] as Map;
  row([
    'Фильтры: ${filters.isEmpty ? 'все назначения' : filters.entries.map((e) => '${e.key}: ${e.value}').join('; ')}',
  ]);
  row(
    [
      'Учебный год',
      'Преподаватель',
      'Предмет',
      'Группа',
      'Вид часов',
      'План, ч',
      'Подтверждено, ч',
      'На проверке, ч',
      'Осталось, ч',
      'Превышение, ч',
    ],
    style: 2,
    height: 38,
  );
  for (final assignment in data['rows'] as List) {
    for (final category in ['main', 'additional']) {
      final progress = assignment['progress'][category] as Map;
      row(
        [
          '${assignment['academicYear']}–${assignment['academicYear'] + 1}',
          assignment['teacher'],
          assignment['subject'],
          assignment['group'],
          category == 'main' ? 'Основные' : 'Допконтроль',
          for (final field in [
            'planned',
            'confirmed',
            'submitted',
            'remaining',
            'excess',
          ])
            progress[field],
        ],
        numbers: true,
        height: 44,
      );
    }
  }
  final lastDataRow = rowNumber;
  if ((data['rows'] as List).isEmpty)
    row(['Нет назначений по выбранным фильтрам']);
  row([]);
  for (final category in ['main', 'additional']) {
    final total = data['totals'][category] as Map;
    row(
      [
        'Итого',
        '',
        '',
        '',
        category == 'main' ? 'Основные' : 'Допконтроль',
        for (final field in [
          'planned',
          'confirmed',
          'submitted',
          'remaining',
          'excess',
        ])
          total[field],
      ],
      numbers: true,
      style: 1,
      height: 30,
    );
    if (total['missingPlans'] != 0) {
      row([
        'Без плана (${category == 'main' ? 'основные' : 'допконтроль'}): ${total['missingPlans']}. План и остаток в итоге — только по заданным планам.',
      ]);
    }
  }
  file(
    '[Content_Types].xml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>''',
  );
  file(
    '_rels/.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  file(
    'xl/workbook.xml',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Учебная нагрузка" sheetId="1" r:id="rId1"/></sheets></workbook>',
  );
  file(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
  );
  file(
    'xl/styles.xml',
    '''<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="0.###############"/></numFmts>
<fonts count="3"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="16"/><name val="Calibri"/><color rgb="FF1A5CA8"/></font><font><b/><sz val="11"/><name val="Calibri"/><color rgb="FFFFFFFF"/></font></fonts>
<fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1A5CA8"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFF1D6"/><bgColor indexed="64"/></patternFill></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="5"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="0" fontId="0" fillId="3" borderId="0" xfId="0"/></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>''',
  );
  file(
    'xl/worksheets/sheet1.xml',
    '''<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:J$rowNumber"/><sheetViews><sheetView workbookViewId="0"><pane xSplit="4" ySplit="6" topLeftCell="E7" activePane="bottomRight" state="frozen"/></sheetView></sheetViews><cols><col min="1" max="1" width="16" customWidth="1"/><col min="2" max="3" width="34" customWidth="1"/><col min="4" max="5" width="20" customWidth="1"/><col min="6" max="10" width="20" customWidth="1"/></cols><sheetData>$body</sheetData><autoFilter ref="A6:J$lastDataRow"/><mergeCells count="5"><mergeCell ref="A1:J1"/><mergeCell ref="A2:J2"/><mergeCell ref="A3:J3"/><mergeCell ref="A4:J4"/><mergeCell ref="A5:J5"/></mergeCells><pageMargins left="0.3" right="0.3" top="0.5" bottom="0.5" header="0.2" footer="0.2"/><pageSetup orientation="landscape" paperSize="9" fitToWidth="1" fitToHeight="0"/></worksheet>''',
  );
  return ZipEncoder().encode(archive);
}
