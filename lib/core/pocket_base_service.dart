import 'package:pocketbase/pocketbase.dart';

import '../features/auth/models/app_user.dart';
import '../features/teacher/models/assignment.dart';
import '../features/teacher/models/vychitka_entry.dart';
import '../features/teacher/models/zamena.dart';
import 'constants.dart';

/// Единственный класс, который взаимодействует с PocketBase.
/// Инкапсулирует нормализацию relations: доменные модели остаются плоскими,
/// а маппинг «имя ↔ profileId», «entry ↔ assignment» выполняется здесь.
class PocketBaseService {
  PocketBaseService(this.baseUrl);

  final String baseUrl;
  late final PocketBase _pb;

  PocketBase get pb => _pb;

  Future<void> init() async {
    _pb = PocketBase(baseUrl, reuseHTTPClient: true);
  }

  void logout() {
    _pb.authStore.clear();
    _invalidateProfiles();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _s(RecordModel r, String key) {
    final v = r.data[key];
    return v is String ? v : (v?.toString() ?? '');
  }

  String? _ns(RecordModel r, String key) {
    final v = r.data[key];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  double _d(RecordModel r, String key) {
    final v = r.data[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  int _i(RecordModel r, String key) {
    final v = r.data[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  DateTime? _dt(RecordModel r, String key) {
    final v = r.data[key];
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  UserRole _role(RecordModel profile) =>
      _s(profile, 'role') == 'admin' ? UserRole.admin : UserRole.teacher;

  /// Профили (user_profiles), загруженные один раз за сессию и кэшируемые.
  /// Профили появляются редко (чаще всего при первом запуске/засеве), поэтому
  /// повторная загрузка всей коллекции на каждый запрос не нужна.
  List<RecordModel>? _profilesCache;

  /// Загружает (или возвращает закэшированные) профили.
  Future<List<RecordModel>> _profiles() async {
    if (_profilesCache != null) return _profilesCache!;
    final list = await _pb.collection(AppConstants.profilesColl)
        .getFullList(sort: '+display_name');
    _profilesCache = list;
    return list;
  }

  /// Сбрасывает кэш профилей (после login/logout или засева данных).
  void _invalidateProfiles() => _profilesCache = null;

  /// Ищет profileId (user_profiles) по display_name.
  Future<String?> _profileIdOf(String name) async {
    final p = await _profileByDisplayName(name);
    return p?.id;
  }

  /// Ищет профиль (user_profiles) по display_name.
  Future<RecordModel?> _profileByDisplayName(String name) async {
    final profiles = await _profiles();
    for (final p in profiles) {
      if (p.data['display_name'] == name) return p;
    }
    return null;
  }

  /// Ищет профиль (user_profiles) по id связанной auth-записи.
  Future<RecordModel?> _profileOfAuth(String authId) async {
    final profiles = await _profiles();
    for (final p in profiles) {
      if (_ns(p, 'user') == authId) return p;
    }
    return null;
  }

  /// Строит текущего пользователя из authStore.
  Future<AppUser?> _currentUser() async {
    final auth = _pb.authStore.record;
    if (auth == null) return null;
    final profile = await _profileOfAuth(auth.id);
    if (profile == null) return null;
    return AppUser(
      id: auth.id,
      profileId: profile.id,
      name: _s(profile, 'display_name'),
      role: _role(profile),
    );
  }

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<AppUser?> login(String name, String password) async {
    final profile = await _profileByDisplayName(name);
    if (profile == null) return null;
    final email = _s(profile, 'email').trim();
    if (email.isEmpty) return null;
    try {
      await _pb.collection(AppConstants.usersColl)
          .authWithPassword(email, password);
    } catch (_) {
      return null;
    }
    _invalidateProfiles();
    return _currentUser();
  }

  Future<List<AppUser>> getAllUsers() async {
    final profiles = await _profiles();
    final result = <AppUser>[];
    for (final p in profiles) {
      final authId = _ns(p, 'user') ?? '';
      final name = _s(p, 'display_name');
      result.add(AppUser(
        id: authId,
        profileId: p.id,
        name: name,
        role: _role(p),
      ));
    }
    return result;
  }

  // ─── Assignments ──────────────────────────────────────────────────────────

  Future<List<Assignment>> getAssignments(String teacherName, int year) async {
    final profileId = await _profileIdOf(teacherName);
    if (profileId == null) return [];
    final rows = await _pb.collection(AppConstants.assignmentsColl).getFullList(
          filter: _pb.filter('teacher = {:id} && year = {:year}', {
            'id': profileId,
            'year': year,
          }),
        );
    return rows
        .map((r) => Assignment(
              teacher: teacherName,
              subject: _s(r, 'subject'),
              group: _s(r, 'group'),
              year: _i(r, 'year'),
            ))
        .toList();
  }

  // ─── Vychitki ─────────────────────────────────────────────────────────────

  /// Статусы всех месяцев учебного года одним запросом: тянет все вычитки
  /// профиля за указанный академический год и агрегирует статусы по месяцам.
  Future<Map<String, VychitkaStatus>> getMonthStatusesForYear(
    String teacher,
    int academicYearStart,
  ) async {
    final profileId = await _profileIdOf(teacher);
    if (profileId == null) return {};

    final entries = await _pb.collection(AppConstants.vychitkiColl).getFullList(
      filter: _pb.filter(
        'assignment.teacher = {:id} && year >= {:y0} && year <= {:y1}',
        {
          'id': profileId,
          'y0': academicYearStart,
          'y1': academicYearStart + 1,
        },
      ),
    );

    final map = <String, VychitkaStatus>{};
    for (final r in entries) {
      final month = _s(r, 'month');
      final status = _parseStatus(_s(r, 'status'));
      if (month.isEmpty) continue;
      final existing = map[month];
      if (existing == null || status.index > existing.index) {
        map[month] = status;
      }
    }
    return map;
  }

  Future<List<VychitkaEntry>> getVychitki({
    String? teacher,
    String? month,
    int? year,
  }) async {
    final filters = <String>[];
    final params = <String, Object?>{};
    if (teacher != null) {
      final profileId = await _profileIdOf(teacher);
      if (profileId == null) return [];
      filters.add('assignment.teacher = {:teacher}');
      params['teacher'] = profileId;
    }
    if (month != null) {
      filters.add('month = {:month}');
      params['month'] = month;
    }
    if (year != null) {
      filters.add('year = {:year}');
      params['year'] = year;
    }
    final filter = _pb.filter(
      filters.isEmpty ? '' : filters.join(' && '),
      params,
    );

    final rows = await _pb.collection(AppConstants.vychitkiColl).getFullList(
          filter: filter.isEmpty ? null : filter,
          expand: 'assignment, assignment.teacher, confirmed_by, confirmed_by.user',
        );

    return rows.map((r) => _entryFromRecord(r)).toList();
  }

  VychitkaEntry _entryFromRecord(RecordModel r) {
    final expand = r.data['expand'];
    RecordModel? assignment;
    if (expand is Map && expand['assignment'] is Map) {
      final a = RecordModel(expand['assignment'] as Map<String, dynamic>);
      assignment = a;
    }

    String teacherName = '';
    if (assignment != null) {
      final aExpand = assignment.data['expand'];
      if (aExpand is Map && aExpand['teacher'] is Map) {
        final t = RecordModel(aExpand['teacher'] as Map<String, dynamic>);
        teacherName = _ns(t, 'display_name') ?? teacherName;
      }
    }

    final subject = assignment == null ? '' : _s(assignment, 'subject');
    final group = assignment == null ? '' : _s(assignment, 'group');

    String? confirmedBy;
    if (expand is Map && expand['confirmed_by'] is Map) {
      // confirmed_by может иметь вложенный user; используем display_name напрямую
      final c = RecordModel(expand['confirmed_by'] as Map<String, dynamic>);
      confirmedBy = _ns(c, 'display_name');
    }

    return VychitkaEntry(
      id: r.id,
      assignmentId: assignment?.id ?? '',
      teacher: teacherName,
      month: _s(r, 'month'),
      year: _i(r, 'year'),
      subject: subject,
      group: group,
      lek: _d(r, 'lek'),
      lrPr: _d(r, 'lrPr'),
      kp: _d(r, 'kp'),
      cons: _d(r, 'cons'),
      dopKontr: _d(r, 'dopKontr'),
      ekz: _d(r, 'ekz'),
      status: _parseStatus(_s(r, 'status')),
      submittedAt: _dt(r, 'submitted_at'),
      confirmedAt: _dt(r, 'confirmed_at'),
      confirmedBy: confirmedBy,
    );
  }

  VychitkaStatus _parseStatus(String s) {
    switch (s) {
      case 'submitted':
        return VychitkaStatus.submitted;
      case 'confirmed':
        return VychitkaStatus.confirmed;
      default:
        return VychitkaStatus.draft;
    }
  }

  String _statusStr(VychitkaStatus s) {
    switch (s) {
      case VychitkaStatus.submitted:
        return 'submitted';
      case VychitkaStatus.confirmed:
        return 'confirmed';
      case VychitkaStatus.draft:
        return 'draft';
    }
  }

  Future<String?> _assignmentIdOf(VychitkaEntry e, String profileId) async {
    final academicYear = AppConstants.academicYearStart(e.month, e.year);
    final rows = await _pb.collection(AppConstants.assignmentsColl).getFullList(
          filter: _pb.filter(
              'teacher = {:id} && subject = {:subject} && group = {:group} && year = {:year}',
              {
                'id': profileId,
                'subject': e.subject,
                'group': e.group,
                'year': academicYear,
              }),
        );
    return rows.isEmpty ? null : rows.first.id;
  }

  /// Сохраняет записи и возвращает их с актуальными `id`/`assignmentId`
  /// (у только что созданных записей сервер присваивает id). Возвращение
  /// обновлённых записей важно, иначе повторное сохранение создаст дубликаты.
  Future<List<VychitkaEntry>> saveEntries(List<VychitkaEntry> entries) async {
    final updated = <VychitkaEntry>[];
    for (final e in entries) {
      updated.add(await _saveEntry(e));
    }
    return updated;
  }

  Future<VychitkaEntry> _saveEntry(VychitkaEntry e) async {
    final profileId = await _profileIdOf(e.teacher);
    if (profileId == null) return e;
    final assignmentId = e.assignmentId.isNotEmpty
        ? e.assignmentId
        : await _assignmentIdOf(e, profileId);
    if (assignmentId == null) return e;

    final body = <String, Object?>{
      // assignment, month, year остаются без изменений при update
      'lek': e.lek,
      'lrPr': e.lrPr,
      'kp': e.kp,
      'cons': e.cons,
      'dopKontr': e.dopKontr,
      'ekz': e.ekz,
    };

    final isNew = e.id.isEmpty || e.assignmentId.isEmpty;
    if (isNew) {
      final created =
          await _pb.collection(AppConstants.vychitkiColl).create(body: {
        'assignment': assignmentId,
        'month': e.month,
        'year': e.year,
        'status': _statusStr(e.status),
        'submitted_at': e.submittedAt?.toIso8601String() ?? '',
        'confirmed_at': e.confirmedAt?.toIso8601String() ?? '',
        'confirmed_by': '',
        ...body,
      });
      return e.copyWith(id: created.id, assignmentId: assignmentId);
    } else {
      // Зафиксированная (confirmed) запись заблокирована навсегда.
      final existing = await _pb
          .collection(AppConstants.vychitkiColl)
          .getOne(e.id, query: {'fields': 'status'});
      if (_s(existing, 'status') == _statusStr(VychitkaStatus.confirmed)) {
        return e;
      }
      await _pb.collection(AppConstants.vychitkiColl).update(e.id, body: body);
      return e;
    }
  }

  Future<void> _updateStatusForMonth(
    String teacher,
    String month,
    int year,
    VychitkaStatus status, {
    String? confirmedBy,
  }) async {
    final profileId = await _profileIdOf(teacher);
    if (profileId == null) return;
    final rows = await _pb.collection(AppConstants.vychitkiColl).getFullList(
          filter: _pb.filter(
              'assignment.teacher = {:id} && month = {:month} && year = {:year}',
              {'id': profileId, 'month': month, 'year': year}),
        );
    for (final r in rows) {
      // Зафиксированную запись нельзя менять.
      if (_s(r, 'status') == _statusStr(VychitkaStatus.confirmed)) {
        continue;
      }
      final body = <String, Object?>{'status': _statusStr(status)};
      if (status == VychitkaStatus.submitted) {
        body['submitted_at'] = DateTime.now().toIso8601String();
      } else if (status == VychitkaStatus.confirmed) {
        final byProfileId = confirmedBy == null
            ? null
            : await _profileIdOf(confirmedBy);
        body['confirmed_at'] = DateTime.now().toIso8601String();
        body['confirmed_by'] = byProfileId ?? '';
      }
      await _pb.collection(AppConstants.vychitkiColl).update(r.id, body: body);
    }
  }

  Future<void> submitMonth(String teacher, String month, int year) =>
      _updateStatusForMonth(teacher, month, year, VychitkaStatus.submitted);

  Future<void> confirmMonth(
    String teacher,
    String month,
    int year,
    String confirmedBy,
  ) =>
      _updateStatusForMonth(
        teacher,
        month,
        year,
        VychitkaStatus.confirmed,
        confirmedBy: confirmedBy,
      );

  Future<void> rejectMonth(String teacher, String month, int year) =>
      _updateStatusForMonth(teacher, month, year, VychitkaStatus.draft);

  // ─── Zameny ───────────────────────────────────────────────────────────────

  Future<List<Zamena>> getZameny(
      String teacher, String month, int year) async {
    final profileId = await _profileIdOf(teacher);
    if (profileId == null) return [];
    final rows = await _pb.collection(AppConstants.zamenyColl).getFullList(
          filter: _pb.filter(
              'teacher = {:id} && month = {:month} && year = {:year}',
              {'id': profileId, 'month': month, 'year': year}),
        );
    return rows
        .map((r) => Zamena(
              id: r.id,
              teacher: teacher,
              month: _s(r, 'month'),
              year: _i(r, 'year'),
              group: _s(r, 'group'),
              date: _s(r, 'date'),
              hours: _d(r, 'hours'),
            ))
        .toList();
  }

  Future<void> saveZamena(Zamena z) async {
    final profileId = await _profileIdOf(z.teacher);
    if (profileId == null) return;
    await _pb.collection(AppConstants.zamenyColl).create(body: {
      'teacher': profileId,
      'month': z.month,
      'year': z.year,
      'group': z.group,
      'date': z.date,
      'hours': z.hours,
    });
  }

  Future<void> deleteZamena(
      String teacher, String month, int year, String date) async {
    final profileId = await _profileIdOf(teacher);
    if (profileId == null) return;
    final rows = await _pb.collection(AppConstants.zamenyColl).getFullList(
          filter: _pb.filter(
              'teacher = {:id} && month = {:month} && year = {:year} && date = {:date}',
              {'id': profileId, 'month': month, 'year': year, 'date': date}),
        );
    for (final r in rows) {
      await _pb.collection(AppConstants.zamenyColl).delete(r.id);
    }
  }
}
