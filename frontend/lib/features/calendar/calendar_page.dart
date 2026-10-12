import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/widgets.dart';
import '../content/content_editor_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  late Future<List<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(
      _month.year,
      _month.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    final result = await context.read<AuthController>().api.get(
      'calendar/?start=${Uri.encodeComponent(start.toUtc().toIso8601String())}&end=${Uri.encodeComponent(end.toUtc().toIso8601String())}',
    );
    final list = result is Map
        ? result['results'] as List? ?? const []
        : result as List? ?? const [];
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _changeMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);
      _selected = DateTime(_month.year, _month.month, 1);
      _events = _load();
    });
  }

  DateTime? _date(Map<String, dynamic> item) {
    try {
      return DateTime.parse(item['scheduled_for'] as String).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _open(Map<String, dynamic> schedule) async {
    try {
      final content = Map<String, dynamic>.from(
        await context.read<AuthController>().api.get(
          'content/${schedule['content']}/',
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ContentEditorPage(item: content)),
      );
      if (mounted) setState(() => _events = _load());
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _events,
    builder: (context, snapshot) {
      final items = snapshot.data ?? const <Map<String, dynamic>>[];
      final dayItems = items.where((item) {
        final date = _date(item);
        return date != null &&
            date.year == _selected.year &&
            date.month == _selected.month &&
            date.day == _selected.day;
      }).toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
        children: [
          const SectionHeading(
            title: 'Content calendar',
            subtitle:
                'Plan your publishing rhythm and adjust dates as plans change.',
          ),
          const SizedBox(height: 20),
          if (snapshot.hasError)
            InlineError(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _events = _load()),
            )
          else if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(
              padding: EdgeInsets.all(50),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SurfaceCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            DateFormat('MMMM yyyy').format(_month),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                      TextButton(
                        onPressed: () {
                          final now = DateTime.now();
                          setState(() {
                            _month = DateTime(now.year, now.month);
                            _selected = now;
                            _events = _load();
                          });
                        },
                        child: const Text('Today'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _CalendarGrid(
                    month: _month,
                    selected: _selected,
                    items: items,
                    eventDate: _date,
                    onSelect: (date) => setState(() => _selected = date),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d').format(_selected),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${dayItems.length} ${dayItems.length == 1 ? 'post' : 'posts'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (dayItems.isEmpty)
              const SurfaceCard(
                child: EmptyState(
                  title: 'No posts for this day',
                  description:
                      'Choose another date, or schedule a draft from your content editor.',
                ),
              )
            else
              for (final item in dayItems)
                _ScheduleCard(
                  item: item,
                  date: _date(item)!,
                  onOpen: () => _open(item),
                  onChanged: () => setState(() => _events = _load()),
                ),
          ],
        ],
      );
    },
  );
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.selected,
    required this.items,
    required this.eventDate,
    required this.onSelect,
  });
  final DateTime month;
  final DateTime selected;
  final List<Map<String, dynamic>> items;
  final DateTime? Function(Map<String, dynamic>) eventDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final offset = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final count = ((offset + days + 6) ~/ 7) * 7;
    final eventDays = items
        .map(eventDate)
        .whereType<DateTime>()
        .map((date) => '${date.year}-${date.month}-${date.day}')
        .toSet();
    final weekdayHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        .map(
          (day) => Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  day,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);
    return Column(
      children: [
        Row(children: weekdayHeaders),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 48,
          ),
          itemBuilder: (context, index) {
            final day = index - offset + 1;
            if (day < 1 || day > days) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, day);
            final chosen =
                date.year == selected.year &&
                date.month == selected.month &&
                date.day == selected.day;
            final hasEvent = eventDays.contains(
              '${date.year}-${date.month}-${date.day}',
            );
            return InkWell(
              onTap: () => onSelect(date),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: chosen ? AppColors.violet : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: chosen ? Colors.white : AppColors.ink,
                        fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: hasEvent ? AppColors.mint : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    required this.date,
    required this.onOpen,
    required this.onChanged,
  });
  final Map<String, dynamic> item;
  final DateTime date;
  final VoidCallback onOpen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(15),
      child: SurfaceCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 49,
              decoration: BoxDecoration(
                color: AppColors.violetSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('h:mm').format(date),
                    style: const TextStyle(
                      color: AppColors.violet,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    DateFormat('a').format(date),
                    style: const TextStyle(
                      color: AppColors.violet,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${titleCase(item['platform'] as String? ?? '')} · ${titleCase(item['content_type'] as String? ?? 'post')}',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['body_preview'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit or change time',
              onPressed: onOpen,
              icon: const Icon(Icons.edit_outlined, color: AppColors.violet),
            ),
          ],
        ),
      ),
    ),
  );
}
