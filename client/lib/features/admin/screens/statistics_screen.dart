import 'package:flutter/material.dart';
import '../../../core/report_repository.dart';
import '../../../core/download/save_file.dart';
import '../../../core/domain.dart';
import '../../../shared/widgets/assignment_progress.dart';
import '../../../shared/widgets/screen_hint.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, required this.repository});
  final ReportRepository repository;
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic>? _options, _data;
  final _filters = <String, String>{};
  String? _error;
  bool _loading = true, _exporting = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await widget.repository.statisticsOptions();
      if (!mounted) return;
      setState(() {
        _options = options;
        _filters['academicYear'] = '${(options['years'] as List).first}';
      });
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await widget.repository.statistics(Map.of(_filters));
      if (mounted && request == _request) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _export() async {
    final filters = Map<String, String>.of(_filters);
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final bytes = await widget.repository.exportStatistics(filters);
      if (!mounted) return;
      saveFile(bytes, 'нагрузка-${filters['academicYear'] ?? 'все-годы'}.xlsx');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Excel-файл передан браузеру для скачивания')));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _filter(
          String key, String label, List<DropdownMenuItem<String>> items) =>
      SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
              key: ValueKey('$key:${_filters[key]}'),
              initialValue: _filters[key] ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                const DropdownMenuItem(value: '', child: Text('Все')),
                ...items
              ],
              onChanged: _exporting
                  ? null
                  : (value) {
                      setState(() {
                        if (value == null || value.isEmpty) {
                          _filters.remove(key);
                        } else {
                          _filters[key] = value;
                        }
                      });
                      _load();
                    }));

  @override
  Widget build(BuildContext context) {
    final rows = (_data?['rows'] as List?) ?? [];
    return Scaffold(
        appBar: AppBar(title: const Text('Статистика и Excel')),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const ScreenHint(
                      title: 'Годовой план и выполнение',
                      message:
                          'Выберите учебный год и нужные назначения. Остаток считается по подтверждённым часам; часы на проверке показаны отдельно. Черновики и замены не входят в план.'),
                  if (_options != null) ...[
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, runSpacing: 16, children: [
                      _filter('academicYear', 'Учебный год', [
                        for (final year in _options!['years'] as List)
                          DropdownMenuItem(
                              value: '$year', child: Text('$year–${year + 1}'))
                      ]),
                      for (final field in [
                        ('teacher', 'Преподаватель', 'teachers'),
                        ('subject', 'Предмет', 'subjects'),
                        ('group', 'Группа', 'groups')
                      ])
                        _filter(field.$1, field.$2, [
                          for (final item in _options![field.$3] as List)
                            DropdownMenuItem(
                                value: item['id'] as String,
                                child: Text(item['name'] as String,
                                    overflow: TextOverflow.ellipsis))
                        ]),
                    ]),
                    const SizedBox(height: 16),
                    Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                              onPressed: _loading ||
                                      _exporting ||
                                      _data == null ||
                                      rows.isEmpty
                                  ? null
                                  : _export,
                              icon: _exporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.download_outlined),
                              label: Text(_exporting
                                  ? 'Создаём Excel…'
                                  : 'Скачать Excel')),
                          OutlinedButton.icon(
                              onPressed: _exporting
                                  ? null
                                  : () {
                                      setState(_filters.clear);
                                      _load();
                                    },
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('Сбросить фильтры')),
                          Text('Назначений: ${rows.length}'),
                        ]),
                  ],
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                              TextButton(
                                  onPressed:
                                      _options == null ? _initialize : _load,
                                  child: const Text('Повторить'))
                            ])),
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator())),
                  if (!_loading && _data != null && rows.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                            'По выбранным фильтрам назначений нет. Измените фильтры или выберите другой учебный год.')),
                  if (_data != null && rows.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Итоги выборки',
                        style: Theme.of(context).textTheme.titleLarge),
                    for (final category in [
                      ('main', 'Основные часы'),
                      ('additional', 'Допконтроль')
                    ])
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                              '${category.$2}: план ${_data!['totals'][category.$1]['planned']} ч · подтверждено ${_data!['totals'][category.$1]['confirmed']} ч · на проверке ${_data!['totals'][category.$1]['submitted']} ч · осталось ${_data!['totals'][category.$1]['remaining']} ч\n'
                              'Без заданного плана: ${_data!['totals'][category.$1]['missingPlans']}. Остатки и превышения считаются отдельно по назначениям.')),
                    const Divider(height: 32),
                    for (final row in rows)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row['teacher'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text('${row['subject']} · ${row['group']}'),
                                    AssignmentProgressView(
                                        progress: AssignmentProgress.fromJson(
                                            Map<String, dynamic>.from(
                                                row['progress'] as Map)),
                                        academicYear:
                                            row['academicYear'] as int),
                                  ]))),
                  ],
                ]))));
  }
}
