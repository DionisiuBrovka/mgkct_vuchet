import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgkct_teaching_hours/core/decimal_input.dart';
import 'package:mgkct_teaching_hours/core/domain.dart';
import 'package:mgkct_teaching_hours/shared/widgets/assignment_progress.dart';
import 'package:mgkct_teaching_hours/features/teacher/models/editable_report.dart';

import 'report_client_test.dart' as fixtures;

PlanCategory category({String? plan = '0.3'}) => PlanCategory.fromJson({
      'planned': plan,
      'confirmed': '0.1',
      'submitted': '0.2',
      'otherReported': '0.1',
      'remaining': plan == null ? null : '0.2',
      'excess': plan == null ? null : '0',
    });

void main() {
  test('exact comparison detects tiny excess and splits editor categories', () {
    expect(
        DecimalInput.tryParse('0.300000000000000000001')!
            .compareTo(DecimalInput.tryParse('0.3')!),
        1);
    final editor =
        EditableReport.fromReport(ReportDto.fromJson(fixtures.report()));
    final entry = editor.report.entries.single;
    editor.setValue(entry.assignment.id, 'additionalAssessmentHours', '0,7');
    editor.setValue(entry.assignment.id, 'examHours', '0,2');
    expect(editor.categoryFor(entry, additional: false).canonical, '0.5');
    expect(editor.categoryFor(entry, additional: true).canonical, '0.7');
    expect(editor.input(), isNotNull);
  });

  testWidgets(
      'narrow teacher form warns in color without double counting current report',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> show(String current) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AssignmentProgressView(
                    progress: AssignmentProgress(
                        main: category(), additional: category(plan: null)),
                    academicYear: 2026,
                    currentMain: DecimalInput.tryParse(current),
                    currentAdditional: DecimalInput.tryParse('0'),
                    editing: true)))));
    await show('0.2');
    expect(find.text('План превышен. Отправка разрешена.'), findsNothing);
    expect(find.text('С учётом этого отчёта и часов на проверке: 0.3 ч'),
        findsOneWidget);
    await show('0.200000000000000000001');
    final warning = find.text('План превышен. Отправка разрешена.');
    expect(warning, findsOneWidget);
    final text = tester.widget<Text>(warning);
    expect(
        text.style!.color, Theme.of(tester.element(warning)).colorScheme.error);
    expect(find.text('Допконтроль: план не задан'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin sees confirmed, pending and remaining separately',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AssignmentProgressView(
                progress: AssignmentProgress(
                    main: category(), additional: category()),
                academicYear: 2026))));
    expect(find.text('Вычитано и подтверждено: 0.1 ч'), findsNWidgets(2));
    expect(find.text('На проверке: 0.2 ч'), findsNWidgets(2));
    expect(find.text('Осталось по подтверждённым: 0.2 ч'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
