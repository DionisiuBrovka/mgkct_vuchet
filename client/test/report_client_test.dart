import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mgkct_teaching_hours/core/api_service.dart';
import 'package:mgkct_teaching_hours/core/domain.dart';
import 'package:mgkct_teaching_hours/core/report_repository.dart';
import 'package:mgkct_teaching_hours/features/teacher/cubit/teaching_report_cubit.dart';
import 'package:mgkct_teaching_hours/features/teacher/cubit/teaching_report_state.dart';
import 'package:mgkct_teaching_hours/features/teacher/models/editable_report.dart';

Map<String, dynamic> report({String status = 'draft'}) => {
      'id': 'report',
      'teacher': {'id': 'teacher-id', 'name': 'Иванов И.И.', 'role': 'teacher'},
      'period': {'year': 2026, 'month': 9},
      'status': status,
      'revision': 1,
      'entries': [
        {
          'id': 'entry-id',
          'assignment': {
            'id': 'assignment-id',
            'subject': 'Математика',
            'group': 'ПР-21'
          },
          'lectureHours': '0.1',
          'practicalHours': '0.2',
          'courseProjectHours': '0',
          'consultationHours': '0',
          'additionalAssessmentHours': '0',
          'examHours': '0',
          'totalHours': '0.3'
        }
      ],
      'substitutions': [],
      'totals': {
        'lectureHours': '0.1',
        'practicalHours': '0.2',
        'courseProjectHours': '0',
        'consultationHours': '0',
        'additionalAssessmentHours': '0',
        'examHours': '0',
        'assignmentTotal': '0.3',
        'substitutionTotal': '0',
        'grandTotal': '0.3'
      }
    };

void main() {
  test('failed save preserves raw unfinished and long decimal input', () async {
    final api =
        ApiService('http://localhost', client: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode(report()), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode({'message': 'Конфликт'}), 409,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(api.close);
    final cubit = TeachingReportCubit(ReportRepository(api));
    addTearDown(cubit.close);
    await cubit.loadMonth('teacher-id', 2026, 9);
    expect(cubit.state, isA<TeachingReportLoaded>(), reason: '${cubit.state}');
    cubit.updateValue(
        'assignment-id', 'lectureHours', '1000,125000000000000000001');
    await cubit.saveDraft();
    final state = cubit.state as TeachingReportLoaded;
    expect(state.editor.value('assignment-id', 'lectureHours'),
        '1000,125000000000000000001');
    expect(state.error, 'Проверьте значения часов');
  });

  test('submit issues one aggregate request with exact decimal strings',
      () async {
    var writes = 0;
    final api =
        ApiService('http://localhost', client: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode(report()), 200,
            headers: {'content-type': 'application/json'});
      }
      writes++;
      final input = jsonDecode(request.body) as Map<String, dynamic>;
      expect(input['entries'][0]['lectureHours'], '0.1');
      expect(request.url.path.endsWith('/submit'), isTrue);
      return http.Response(jsonEncode(report(status: 'submitted')), 200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(api.close);
    final cubit = TeachingReportCubit(ReportRepository(api));
    addTearDown(cubit.close);
    await cubit.loadMonth('teacher-id', 2026, 9);
    expect(cubit.state, isA<TeachingReportLoaded>(), reason: '${cubit.state}');
    await cubit.submit();
    expect(writes, 1);
    expect((cubit.state as TeachingReportLoaded).editor.report.status.name,
        'submitted');
  });

  test(
      'substitution edits retain server id and identical local rows are distinct',
      () {
    final editor = EditableReport.fromReport(ReportDto.fromJson(report()));
    final first = EditableSubstitution(
        date: '2026-09-10', description: 'Группа ПР-21', hours: '1,5');
    final second = EditableSubstitution(
        date: '2026-09-10', description: 'Группа ПР-21', hours: '1,5');
    editor.substitutions.addAll([first, second]);
    first.description = 'Группа ПР-22';
    expect(first.key, isNot(second.key));
    final input = editor.input()!;
    expect(input['substitutions'][0]['id'], isNull);
    expect(input['substitutions'][0]['hours'], '1.5');
  });
}
