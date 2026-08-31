import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mgkct_teaching_hours/core/pocket_base_service.dart';
import 'package:mgkct_teaching_hours/features/auth/models/app_user.dart';
import 'package:mgkct_teaching_hours/features/teacher/models/substitution.dart';
import 'package:mgkct_teaching_hours/features/teacher/models/teaching_report_entry.dart';
import 'package:mgkct_teaching_hours/features/teacher/repository/teaching_report_repository.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('report workflow and substitutions use the migrated API', () async {
    // All accounts and records are created in a disposable database.
    final root = Directory.current.path;
    final binary = '$root/tools/pocketbase/pocketbase';
    expect(File(binary).existsSync(), isTrue,
        reason:
            'Install the local PocketBase binary before running this test.');
    final directory =
        await Directory.systemTemp.createTemp('teaching-hours-api-');
    addTearDown(() => directory.delete(recursive: true));
    final flags = [
      '--dir=${directory.path}/data',
      '--migrationsDir=$root/tools/pocketbase/pb_migrations',
      '--automigrate=false',
    ];
    const password = 'TemporaryApiTest123!';
    final setup = await Process.run(binary, [
      'superuser',
      'upsert',
      'test@example.com',
      password,
      ...flags,
    ]);
    expect(setup.exitCode, 0, reason: '${setup.stdout}\n${setup.stderr}');

    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final server = await Process.start(binary, [
      'serve',
      '--http=127.0.0.1:$port',
      ...flags,
    ]);
    final stdoutDone = server.stdout.drain<void>();
    final stderrDone = server.stderr.drain<void>();
    addTearDown(() async {
      server.kill();
      await server.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
        server.kill(ProcessSignal.sigkill);
        return server.exitCode;
      });
      await Future.wait([stdoutDone, stderrDone]);
    });

    final url = 'http://127.0.0.1:$port';
    final admin = PocketBase(url, reuseHTTPClient: true);
    addTearDown(admin.close);
    for (var attempt = 0;; attempt++) {
      try {
        await admin.health.check();
        break;
      } catch (_) {
        if (attempt >= 99) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    await admin
        .collection('_superusers')
        .authWithPassword('test@example.com', password);
    Future<RecordModel> createProfile(
        String email, String name, String role) async {
      final account = await admin.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
      });
      return admin.collection('user_profiles').create(body: {
        'user': account.id,
        'email': email,
        'display_name': name,
        'role': role,
      });
    }

    const teacherName = 'Тестовый преподаватель';
    const reviewerName = 'Тестовый завуч';
    final teacher =
        await createProfile('teacher@example.com', teacherName, 'teacher');
    final reviewer =
        await createProfile('reviewer@example.com', reviewerName, 'admin');
    final assignment = await admin.collection('assignments').create(body: {
      'teacher': teacher.id,
      'subject': 'Математика',
      'group': 'ПР-21',
      'year': 2026,
    });

    final service = PocketBaseService(url);
    await service.init();
    addTearDown(service.pb.close);
    final repository = TeachingReportRepository(service);
    final user = await service.login(teacherName, password);
    expect(user?.role, UserRole.teacher);
    expect(user?.profileId, teacher.id);
    expect((await repository.getAssignments(teacherName, 2026)).single.subject,
        'Математика');

    const month = 'Сентябрь';
    const draft = TeachingReportEntry(
      id: '',
      teacher: teacherName,
      month: month,
      year: 2026,
      subject: 'Математика',
      group: 'ПР-21',
      lectureHours: 2.5,
      practicalHours: 4.25,
      courseProjectHours: 3,
      consultationHours: 1.5,
      additionalAssessmentHours: 2,
      examHours: 6,
    );
    final saved = (await repository.saveOrUpdateEntries([draft])).single;
    expect(saved.id, isNotEmpty);
    expect(saved.assignmentId, assignment.id);
    await repository.saveOrUpdateEntries([saved.copyWith(lectureHours: 7.5)]);
    final loaded =
        (await repository.getEntries(teacherName, month, 2026)).single;
    expect(loaded, saved.copyWith(lectureHours: 7.5));
    expect(loaded.totalHours, 24.25);
    final raw =
        await admin.collection('teaching_report_entries').getOne(saved.id);
    expect(raw.data['lecture_hours'], 7.5);
    expect(raw.data['practical_hours'], 4.25);
    expect(raw.data['course_project_hours'], 3);
    expect(raw.data['consultation_hours'], 1.5);
    expect(raw.data['additional_assessment_hours'], 2);
    expect(raw.data['exam_hours'], 6);

    const substitution = Substitution(
      teacher: teacherName,
      month: month,
      year: 2026,
      group: 'ПР-22',
      date: '15.09.2026',
      hours: 1.5,
    );
    await repository.saveSubstitution(substitution);
    final substitutions =
        await repository.getSubstitutions(teacherName, month, 2026);
    expect(substitutions.single.id, isNotEmpty);
    expect(substitutions.single.copyWith(id: ''), substitution);
    await repository.deleteSubstitution(
        teacherName, month, 2026, substitution.date);
    expect(
        await repository.getSubstitutions(teacherName, month, 2026), isEmpty);
    await repository.saveSubstitution(substitution);

    await repository.submitMonth(teacherName, month, 2026);
    expect((await repository.getMonthStatusesForYear(teacherName, 2026))[month],
        TeachingReportStatus.submitted);
    service.logout();
    expect((await service.login(reviewerName, password))?.role, UserRole.admin);
    await repository.rejectMonth(teacherName, month, 2026);
    expect(
        (await repository.getEntries(teacherName, month, 2026)).single.status,
        TeachingReportStatus.draft);
    service.logout();
    await service.login(teacherName, password);
    await repository.submitMonth(teacherName, month, 2026);
    service.logout();
    await service.login(reviewerName, password);
    await repository.confirmMonth(teacherName, month, 2026, reviewerName);
    final confirmed =
        (await repository.getEntries(teacherName, month, 2026)).single;
    expect(confirmed.status, TeachingReportStatus.confirmed);
    expect(confirmed.confirmedBy, reviewerName);
    expect(confirmed.submittedAt, isNotNull);
    expect(confirmed.confirmedAt, isNotNull);
    expect((await repository.getMonthStatusesForAll(month, 2026))[teacherName],
        TeachingReportStatus.confirmed);
    final confirmedRaw =
        await admin.collection('teaching_report_entries').getOne(saved.id);
    expect(confirmedRaw.data['confirmed_by'], reviewer.id);

    service.logout();
    await service.login(teacherName, password);
    await repository
        .saveOrUpdateEntries([confirmed.copyWith(lectureHours: 99)]);
    expect(
        (await repository.getEntries(teacherName, month, 2026))
            .single
            .lectureHours,
        7.5);
    expect(
        (await repository.getSubstitutions(teacherName, month, 2026))
            .single
            .hours,
        1.5);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
