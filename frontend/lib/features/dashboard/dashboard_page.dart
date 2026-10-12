import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.onCreate,
    required this.onOpenLibrary,
  });
  final VoidCallback onCreate;
  final VoidCallback onOpenLibrary;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _dashboard;

  @override
  void initState() {
    super.initState();
    _dashboard = _load();
  }

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    await context.read<AuthController>().api.get('dashboard/'),
  );

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthController>().user?['first_name'] as String?;
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(28),
            children: [
              SectionHeading(
                title:
                    'Good ${_greeting()}, ${name?.isNotEmpty == true ? name : 'creator'}',
                subtitle: 'Your content workspace is ready.',
              ),
              const SizedBox(height: 22),
              InlineError(
                message: snapshot.error.toString(),
                onRetry: () => setState(() => _dashboard = _load()),
              ),
            ],
          );
        }
        final data = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return ListView(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SectionHeading(
                        title:
                            'Good ${_greeting()}, ${name?.isNotEmpty == true ? name : 'creator'}',
                        subtitle:
                            'A little progress today makes a lot of content tomorrow.',
                      ),
                    ),
                    if (!compact)
                      PrimaryAction(
                        label: 'Create content',
                        onPressed: widget.onCreate,
                      ),
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PrimaryAction(
                      label: 'Create content',
                      onPressed: widget.onCreate,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _Metrics(data: data, compact: compact),
                const SizedBox(height: 22),
                if (compact) ...[
                  _RecentCard(
                    items: _asList(data['recent_content']),
                    onSeeAll: widget.onOpenLibrary,
                    onCreate: widget.onCreate,
                  ),
                  const SizedBox(height: 18),
                  _UpcomingCard(
                    items: _asList(data['upcoming']),
                    onCreate: widget.onCreate,
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _RecentCard(
                          items: _asList(data['recent_content']),
                          onSeeAll: widget.onOpenLibrary,
                          onCreate: widget.onCreate,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 4,
                        child: _UpcomingCard(
                          items: _asList(data['upcoming']),
                          onCreate: widget.onCreate,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                _WorkflowTip(),
              ],
            );
          },
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  List<Map<String, dynamic>> _asList(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data, required this.compact});
  final Map<String, dynamic> data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Metric(
        'Sources',
        data['total_sources'] ?? 0,
        Icons.inventory_2_outlined,
        AppColors.violet,
        AppColors.violetSoft,
      ),
      _Metric(
        'Generated content',
        data['generated_content'] ?? 0,
        Icons.auto_awesome_outlined,
        AppColors.mint,
        AppColors.mintSoft,
      ),
      _Metric(
        'Drafts',
        data['drafts'] ?? 0,
        Icons.edit_note_rounded,
        AppColors.orange,
        const Color(0xFFFFF0E5),
      ),
      _Metric(
        'Scheduled',
        data['scheduled_posts'] ?? 0,
        Icons.calendar_today_outlined,
        const Color(0xFF537CBA),
        const Color(0xFFEAF1FB),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 460 ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 124,
          ),
          itemBuilder: (context, index) => SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cards[index].soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        cards[index].icon,
                        size: 17,
                        color: cards[index].color,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.muted,
                      size: 18,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${cards[index].value}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  cards[index].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color, this.soft);
  final String label;
  final Object value;
  final IconData icon;
  final Color color;
  final Color soft;
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.items,
    required this.onSeeAll,
    required this.onCreate,
  });
  final List<Map<String, dynamic>> items;
  final VoidCallback onSeeAll;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent content',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('View library')),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          EmptyState(
            title: 'Your library starts here',
            description:
                'Create a source and turn it into platform-ready posts.',
            action: PrimaryAction(
              label: 'Create your first content',
              onPressed: onCreate,
            ),
          )
        else
          for (final item in items.take(5)) _RecentRow(item: item),
      ],
    ),
  );
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final body = (item['body'] as String? ?? '').replaceAll('\n', ' ');
    final platform = item['platform'] as String? ?? '';
    final platformIcon = switch (platform) {
      'instagram' => Icons.camera_alt_outlined,
      'facebook' => Icons.groups_outlined,
      _ => Icons.work_outline_rounded,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: AppColors.violetSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(platformIcon, size: 18, color: AppColors.violet),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${titleCase(item['content_type'] as String? ?? 'caption')} · ${titleCase(platform)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body.isEmpty ? 'No text yet' : body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(status: item['status'] as String? ?? 'draft'),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.items, required this.onCreate});
  final List<Map<String, dynamic>> items;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coming up', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 15),
        if (items.isEmpty)
          const EmptyState(
            title: 'Nothing scheduled yet',
            description: 'When you schedule a post, it will show up here.',
          )
        else
          for (final item in items) _UpcomingRow(item: item),
      ],
    ),
  );
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    DateTime? time;
    try {
      time = DateTime.parse(item['scheduled_for'] as String).toLocal();
    } catch (_) {}
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time == null ? '--' : DateFormat('d').format(time),
                  style: const TextStyle(
                    color: AppColors.violet,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Text(
                  time == null
                      ? '---'
                      : DateFormat('MMM').format(time).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${titleCase(item['platform'] as String? ?? '')} · ${titleCase(item['content_type'] as String? ?? 'post')}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time == null
                      ? 'Time unavailable'
                      : DateFormat('EEE · h:mm a').format(time),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.muted,
            size: 13,
          ),
        ],
      ),
    );
  }
}

class _WorkflowTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEAFF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.violet,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A good source can become a week of ideas.',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Start with a transcript, a note, or a recording. ReContent helps shape each version for its platform.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
