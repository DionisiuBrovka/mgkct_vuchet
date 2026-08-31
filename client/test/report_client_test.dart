import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mgkct_teaching_hours/core/api_service.dart';
import 'package:mgkct_teaching_hours/features/admin/cubit/admin_cubit.dart';
import 'package:mgkct_teaching_hours/features/admin/screens/review_screen.dart';
import 'package:mgkct_teaching_hours/features/teacher/cubit/teaching_report_cubit.dart';
import 'package:mgkct_teaching_hours/features/teacher/cubit/teaching_report_state.dart';
import 'package:mgkct_teaching_hours/features/teacher/models/substitution.dart';
import 'package:mgkct_teaching_hours/features/teacher/repository/teaching_report_repository.dart';

Map<String, dynamic> fixture({String status = 'draft'}) => {
      'teacher': 'teacher-id',
      'teacherName': 'Иванов И.И.',
      'month': 'Сентябрь',
      'year': 2026,
      'revision': 1,
      'status': status,
      'entries': [
        {
          'id': 'entry-id',
          'assignmentId': 'assignment-id',
          'subject': 'Математика',
          'group': 'ПР-21',
          'lectureHours': 1,
          'practicalHours': 2,
          'courseProjectHours': 3,
          'consultationHours': 4,
          'additionalAssessmentHours': 5,
          'examHours': 6
        }
      ],
      'substitutions': [],
      'totals': {
        'lectureHours': 1,
        'practicalHours': 2,
        'courseProjectHours': 3,
        'consultationHours': 4,
        'additionalAssessmentHours': 5,
        'examHours': 6,
        'substitutionHours': 0
      },
    };
void main() {
  test('failed save preserves edited hours and local substitutions', () async {
    var writes = 0;
    final api =
        ApiService('http://localhost', client: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode(fixture()), 200,
            headers: {'content-type': 'application/json'});
      }
      writes++;
      expect(jsonDecode(request.body)['entries'][0]['lectureHours'], 9);
      expect(jsonDecode(request.body)['substitutions'], hasLength(1));
      return http.Response(jsonEncode({'message': 'Отчёт уже изменён'}), 409,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(api.close);
    final cubit = TeachingReportCubit(TeachingReportRepository(api));
    addTearDown(cubit.close);
    await cubit.loadMonth('teacher-id', 'Сентябрь', 2026);
    expect(cubit.state, isA<TeachingReportLoaded>(),
        reason: cubit.state is TeachingReportError
            ? (cubit.state as TeachingReportError).message
            : null);
    final entry = (cubit.state as TeachingReportLoaded).entries.single;
    cubit.updateEntry(entry.copyWith(lectureHours: 9));
    const replacement = Substitution(
        teacher: 'teacher-id',
        month: 'Сентябрь',
        year: 2026,
        group: 'ПР-22',
        date: '15.09.2026',
        hours: 2);
    cubit.addSubstitution(replacement);
    cubit.addSubstitution(replacement);
    final first = (cubit.state as TeachingReportLoaded).substitutions.first;
    cubit.deleteSubstitution(first);
    expect((cubit.state as TeachingReportLoaded).substitutions, hasLength(1));
    expect(writes, 0);
    await cubit.saveDraft();
    final loaded = cubit.state as TeachingReportLoaded;
    expect(loaded.entries.single.lectureHours, 9);
    expect(loaded.substitutions, hasLength(1));
    expect(loaded.isSaving, false);
    expect(loaded.error, 'Отчёт уже изменён');
    expect(writes, 1);
  });

  test('submit uses one request and trusts the returned report status',
      () async {
    var writes = 0;
    final api =
        ApiService('http://localhost', client: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode(fixture()), 200,
            headers: {'content-type': 'application/json'});
      }
      writes++;
      expect(request.url.path.endsWith('/submit'), true);
      return http.Response(jsonEncode(fixture(status: 'submitted')), 200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(api.close);
    final cubit = TeachingReportCubit(TeachingReportRepository(api));
    addTearDown(cubit.close);
    await cubit.loadMonth('teacher-id', 'Сентябрь', 2026);
    await cubit.submit();
    expect(
        (cubit.state as TeachingReportLoaded).report.status.name, 'submitted');
    expect(writes, 1);
  });

  testWidgets('confirmed report stays open and has no review actions',
      (tester) async {
    final api = ApiService('http://localhost',
        client: MockClient((_) async => http.Response(
            jsonEncode(fixture(status: 'confirmed')), 200,
            headers: {'content-type': 'application/json'})));
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(
        home: BlocProvider(
            create: (_) => AdminCubit(TeachingReportRepository(api)),
            child: const ReviewScreen(
                teacher: 'teacher-id', month: 'Сентябрь', year: 2026))));
    await tester.pumpAndSettle();
    expect(find.text('Иванов И.И.'), findsOneWidget);
    expect(find.text('✓ Подтвердить'), findsNothing);
    expect(find.text('↩ Вернуть'), findsNothing);
    expect(find.textContaining('Математика'), findsOneWidget);
  });
}
