import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mgkct_teaching_hours/core/api_service.dart';
import 'package:mgkct_teaching_hours/core/report_repository.dart';
import 'package:mgkct_teaching_hours/features/teacher/cubit/periods_cubit.dart';

void main() {
  test('uses the periods returned by the server, not the local clock',
      () async {
    final api = ApiService(
      'http://localhost',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'periods': [
              {
                'academicYear': 2025,
                'year': 2025,
                'month': 9,
                'status': 'draft'
              },
              {
                'academicYear': 2025,
                'year': 2026,
                'month': 7,
                'status': 'submitted'
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(api.close);
    final cubit = PeriodsCubit(ReportRepository(api));
    addTearDown(cubit.close);

    await cubit.load();

    final state = cubit.state as PeriodsLoaded;
    expect(state.periods, hasLength(2));
    expect(state.periods.map((period) => period['month']), [9, 7]);
    expect(state.periods.map((period) => period['year']), [2025, 2026]);
  });

  test('retry replaces an error with the latest server response', () async {
    var requests = 0;
    final api = ApiService(
      'http://localhost',
      client: MockClient((_) async {
        requests++;
        if (requests == 1) {
          return http.Response(jsonEncode({'message': 'Нет связи'}), 503,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
          jsonEncode({
            'periods': [
              {
                'academicYear': 2026,
                'year': 2026,
                'month': 9,
                'status': 'draft'
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);
    final cubit = PeriodsCubit(ReportRepository(api));
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state, isA<PeriodsError>());

    await cubit.load();
    expect(cubit.state, isA<PeriodsLoaded>());
    expect((cubit.state as PeriodsLoaded).periods.single['status'], 'draft');
  });

  test('a late refresh response cannot overwrite newer periods', () async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    var requests = 0;
    final api = ApiService(
      'http://localhost',
      client: MockClient((_) {
        requests++;
        return requests == 1 ? first.future : second.future;
      }),
    );
    addTearDown(api.close);
    final cubit = PeriodsCubit(ReportRepository(api));
    addTearDown(cubit.close);

    final initialLoad = cubit.load();
    final refresh = cubit.load();
    second.complete(http.Response(
      jsonEncode({
        'periods': [
          {
            'academicYear': 2026,
            'year': 2026,
            'month': 10,
            'status': 'submitted'
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await refresh;
    first.complete(http.Response(
      jsonEncode({
        'periods': [
          {'academicYear': 2026, 'year': 2026, 'month': 9, 'status': 'draft'},
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await initialLoad;

    expect((cubit.state as PeriodsLoaded).periods.single['month'], 10);
  });
}
