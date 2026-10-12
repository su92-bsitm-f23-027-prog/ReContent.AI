import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final result = await context.read<AuthController>().api.get('history/');
    final rows = result is Map
        ? result['results'] as List? ?? const []
        : result as List? ?? const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
    children: [
      const SectionHeading(
        title: 'Generation history',
        subtitle:
            'A record of source processing, generated drafts, edits, and schedule changes.',
      ),
      const SizedBox(height: 20),
      SurfaceCard(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              );
            if (snapshot.hasError)
              return InlineError(
                message: snapshot.error.toString(),
                onRetry: () => setState(() => _events = _load()),
              );
            final events = snapshot.data ?? const [];
            if (events.isEmpty)
              return const EmptyState(
                title: 'History will appear here',
                description:
                    'Once you process a source or generate content, you can review those steps here.',
              );
            return Column(
              children: [for (final event in events) _HistoryRow(event: event)],
            );
          },
        ),
      ),
    ],
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final action = event['event_type'] as String? ?? 'updated';
    final details = <String>[];
    if ((event['content_type'] as String? ?? '').isNotEmpty)
      details.add(titleCase(event['content_type'] as String));
    if ((event['platform'] as String? ?? '').isNotEmpty)
      details.add(titleCase(event['platform'] as String));
    if ((event['source_title'] as String? ?? '').isNotEmpty)
      details.add(event['source_title'] as String);
    DateTime? when;
    try {
      when = DateTime.parse(event['created_at'] as String).toLocal();
    } catch (_) {}
    final icon = switch (action) {
      'generated' => Icons.auto_awesome_rounded,
      'edited' => Icons.edit_outlined,
      'scheduled' ||
      'rescheduled' ||
      'cancelled' => Icons.calendar_month_outlined,
      'source_processed' => Icons.subject_rounded,
      _ => Icons.history_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.violetSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.violet, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleCase(action.replaceAll('_', ' ')),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            when == null ? '' : DateFormat('MMM d · h:mm a').format(when),
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
