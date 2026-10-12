import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/widgets.dart';
import 'content_editor_page.dart';

class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({super.key});

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  String _filter = 'all';
  late Future<List<Map<String, dynamic>>> _items;

  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final result = await context.read<AuthController>().api.get(
      'content/${_filter == 'all' ? '' : '?status=$_filter'}',
    );
    final list = result is Map
        ? result['results'] as List? ?? const []
        : result as List? ?? const [];
    return list
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  void _changeFilter(String filter) {
    setState(() {
      _filter = filter;
      _items = _load();
    });
  }

  Future<void> _open(Map<String, dynamic> item) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ContentEditorPage(item: item)));
    if (mounted) setState(() => _items = _load());
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
    children: [
      const SectionHeading(
        title: 'My content',
        subtitle: 'Every draft and scheduled idea, together in one place.',
      ),
      const SizedBox(height: 20),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 7,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => _changeFilter('all'),
                ),
                _FilterChip(
                  label: 'Drafts',
                  selected: _filter == 'draft',
                  onTap: () => _changeFilter('draft'),
                ),
                _FilterChip(
                  label: 'Scheduled',
                  selected: _filter == 'scheduled',
                  onTap: () => _changeFilter('scheduled'),
                ),
                _FilterChip(
                  label: 'Cancelled',
                  selected: _filter == 'cancelled',
                  onTap: () => _changeFilter('cancelled'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                if (snapshot.hasError)
                  return InlineError(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(() => _items = _load()),
                  );
                final items = snapshot.data ?? const [];
                if (items.isEmpty)
                  return EmptyState(
                    title: _filter == 'all'
                        ? 'Your content will appear here'
                        : 'No ${_filter} content',
                    description: _filter == 'all'
                        ? 'Create platform-ready drafts from a source to start your library.'
                        : 'Try another status filter or create some new content.',
                  );
                return Column(
                  children: [
                    for (final item in items)
                      _ContentRow(item: item, onTap: () => _open(item)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: AppColors.violetSoft,
    side: BorderSide(color: selected ? AppColors.violet : AppColors.border),
  );
}

class _ContentRow extends StatelessWidget {
  const _ContentRow({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final platform = item['platform'] as String? ?? '';
    final icon = switch (platform) {
      'instagram' => Icons.camera_alt_outlined,
      'facebook' => Icons.groups_outlined,
      _ => Icons.work_outline_rounded,
    };
    DateTime? scheduled;
    try {
      final raw = item['scheduled_for'];
      if (raw is String) scheduled = DateTime.parse(raw).toLocal();
    } catch (_) {}
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.violetSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.violet, size: 19),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${titleCase(item['content_type'] as String? ?? 'caption')} · ${titleCase(platform)}',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      StatusPill(status: item['status'] as String? ?? 'draft'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    (item['body'] as String? ?? '').replaceAll('\n', ' '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if ((item['source_title'] as String? ?? '')
                          .isNotEmpty) ...[
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          size: 13,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item['source_title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                      if (scheduled != null) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppColors.mint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d · h:mm a').format(scheduled),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
