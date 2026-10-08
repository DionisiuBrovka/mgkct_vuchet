import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mgkct_teaching_hours/core/api_service.dart';
import 'package:mgkct_teaching_hours/core/report_repository.dart';
import 'package:mgkct_teaching_hours/features/admin/screens/statistics_screen.dart';
import 'package:mgkct_teaching_hours/features/admin/screens/admin_home_screen.dart';
import 'package:mgkct_teaching_hours/features/admin/cubit/admin_cubit.dart';
import 'package:mgkct_teaching_hours/features/teacher/screens/substitution_dialog.dart';
import 'package:mgkct_teaching_hours/shared/widgets/hours_input_field.dart';
import 'package:mgkct_teaching_hours/shared/theme/app_theme.dart';
import 'package:mgkct_teaching_hours/injection.dart';

import 'package:mgkct_teaching_hours/features/auth/cubit/auth_cubit.dart';
import 'package:mgkct_teaching_hours/features/auth/repository/auth_repository.dart';
import 'package:mgkct_teaching_hours/features/teacher/cubit/teaching_report_cubit.dart';
import 'package:mgkct_teaching_hours/features/teacher/screens/fill_teaching_report_screen.dart';
import 'report_client_test.dart' as fixture;

Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: child);

void main() {
  testWidgets(
      'hours show inline errors, preserve paste and accept long exact decimals',
      (tester) async {
    var value = '';
    await tester.pumpWidget(app(Scaffold(
        body: HoursInputField(
            label: 'Лекции', value: '', onChanged: (v) => value = v))));
    await tester.enterText(find.byType(TextFormField), '-1');
    await tester.pump();
    expect(find.text('Введите число от 0, например 1,5'), findsOneWidget);
    expect(value, '-1');
    await tester.enterText(find.byType(TextFormField), '1,');
    await tester.pump();
    expect(find.text('Допишите дробную часть'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField), '1234,1234567890123456789');
    await tester.pump();
    expect(find.text('Допишите дробную часть'), findsNothing);
    expect(value, '1234,1234567890123456789');
  });

  testWidgets(
      'substitution form validates required fields and restricts date to report month',
      (tester) async {
    await tester.pumpWidget(
        app(const Scaffold(body: SubstitutionDialog(year: 2026, month: 10))));
    await tester.tap(find.text('Сохранить замену'));
    await tester.pumpAndSettle();
    expect(find.text('Выберите дату'), findsOneWidget);
    expect(find.text('Укажите описание замены'), findsOneWidget);
    final description =
        find.widgetWithText(TextFormField, 'Кого и в какой группе заменяли');
    await tester.enterText(description, 'x' * 510);
    expect(
        tester.widget<TextFormField>(description).controller!.text.length, 500);
    await tester.tap(find.widgetWithText(TextFormField, 'Дата замены'));
    await tester.pumpAndSettle();
    final picker =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(picker.firstDate, DateTime(2026, 10, 1));
    expect(picker.lastDate, DateTime(2026, 10, 31));
    expect(tester.takeException(), isNull);
  });

  for (final width in [360, 1440]) {
    testWidgets(
        'report tabs preserve input and validate hidden hours at ${width}px',
        (tester) async {
      tester.view.physicalSize = Size(width.toDouble(), 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final api =
          ApiService('http://localhost', client: MockClient((request) async {
        final value = request.url.path.endsWith('/me')
            ? {'user': fixture.report()['teacher']}
            : fixture.report();
        if (request.method != 'GET') writes++;
        return http.Response(jsonEncode(value), 200,
            headers: {'content-type': 'application/json'});
      }));
      final auth = AuthCubit(AuthRepository(api));
      final editor = TeachingReportCubit(ReportRepository(api));
      addTearDown(() async {
        await auth.close();
        await editor.close();
        api.close();
      });
      await auth.restore();
      await tester.pumpWidget(app(MultiBlocProvider(providers: [
        BlocProvider.value(value: auth),
        BlocProvider.value(value: editor),
      ], child: const FillTeachingReportScreen(month: 9, year: 2026))));
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<HoursInputField>(find.byType(HoursInputField))
          .map((w) => w.label)
          .toList();
      expect(labels.sublist(4), ['Экзамены', 'Допконтроль']);
      final lecture = find.widgetWithText(TextFormField, 'Лекции');
      await tester.enterText(lecture, '1,');
      await tester.tap(find.text('Замены (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Добавить замену'), findsOneWidget);
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Проверьте поля часов на вкладке «Назначения».'),
          findsOneWidget);
      await tester.tap(find.text('Назначения (1)'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(lecture).controller!.text, '1,');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.enterText(lecture, '1,125');
      await tester.tap(find.text('Замены (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320, 768, 1440]) {
    testWidgets('admin filters and statistics fit ${width}px', (tester) async {
      tester.view.physicalSize = Size(width.toDouble(), 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api =
          ApiService('http://localhost', client: MockClient((request) async {
        final path = request.url.path;
        final value = path.endsWith('/options')
            ? {
                'years': [2026],
                'teachers': [],
                'subjects': [],
                'groups': []
              }
            : path.endsWith('/statistics')
                ? {'rows': [], 'totals': {}}
                : path.endsWith('/periods')
                    ? {
                        'periods': [
                          {'academicYear': 2026}
                        ]
                      }
                    : {
                        'teachers': [
                          {
                            'id': 'teacher00000001',
                            'name':
                                'Очень длинное имя преподавателя для проверки переноса строк',
                            'status': 'submitted'
                          }
                        ]
                      };
        return http.Response(jsonEncode(value), 200,
            headers: {'content-type': 'application/json'});
      }));
      addTearDown(api.close);
      final repo = ReportRepository(api);
      getIt.registerSingleton<ReportRepository>(repo);
      addTearDown(getIt.reset);
      final cubit = AdminCubit(repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(app(
          BlocProvider.value(value: cubit, child: const AdminHomeScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Годовая статистика и Excel'), findsOneWidget);
      await tester.pumpWidget(app(StatisticsScreen(repository: repo)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('По выбранным фильтрам назначений нет'),
          findsOneWidget);
      final export = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Скачать Excel'));
      expect(export.onPressed, isNull);
    });
  }
}
