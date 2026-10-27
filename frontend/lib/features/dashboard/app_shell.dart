import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../calendar/calendar_page.dart';
import '../content/content_library_page.dart';
import '../create/create_content_page.dart';
import '../dashboard/dashboard_page.dart';
import '../history/history_page.dart';
import '../settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;

  static const _destinations = [
    _Destination('Dashboard', Icons.grid_view_rounded),
    _Destination('Create content', Icons.add_circle_outline_rounded),
    _Destination('My content', Icons.library_books_outlined),
    _Destination('Calendar', Icons.calendar_month_outlined),
    _Destination('Generation history', Icons.history_rounded),
    _Destination('Settings', Icons.settings_outlined),
  ];

  void _go(int index) => setState(() => _selected = index);

  Widget _page() => switch (_selected) {
        0 => DashboardPage(onCreate: () => _go(1), onOpenLibrary: () => _go(2)),
        1 => CreateContentPage(onGenerated: () => _go(2)),
        2 => const ContentLibraryPage(),
        3 => const CalendarPage(),
        4 => const HistoryPage(),
        _ => const SettingsPage(),
      };

  Future<void> _openMore() async {
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Generation history'),
              onTap: () => Navigator.pop(context, 4),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context, 5),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Log out'),
              onTap: () => Navigator.pop(context, -1),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || index == null) return;
    if (index == -1) {
      await context.read<AuthController>().logout();
    } else {
      _go(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            _Sidebar(
              selected: _selected,
              destinations: _destinations,
              onSelect: _go,
            ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(title: _destinations[_selected].label),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .015),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_selected),
                        child: _page(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selected < 4 ? _selected : 4,
              onDestinationSelected: (index) =>
                  index == 4 ? _openMore() : _go(index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline_rounded),
                  label: 'Create',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  label: 'Content',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Calendar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz_rounded),
                  label: 'More',
                ),
              ],
            ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.destinations,
    required this.onSelect,
  });
  final int selected;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthController>().user ?? const <String, dynamic>{};
    final name = [
      user['first_name'],
      user['last_name'],
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 24, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 34),
            child: _Brand(),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 10),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (var i = 0; i < destinations.length; i++)
            _NavItem(
              destination: destinations[i],
              selected: selected == i,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.violetSoft,
                  child: Text(
                    (name.isEmpty ? (user['email'] as String? ?? 'R') : name)
                        .characters
                        .first
                        .toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.violet,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Your account' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        user['email'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Log out',
                  onPressed: () => context.read<AuthController>().logout(),
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 17,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: AppColors.violet,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'ReContent',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'AI',
            style: TextStyle(
              color: AppColors.violet,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Material(
          color: selected ? AppColors.violetSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    size: 19,
                    color: selected ? AppColors.violet : AppColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    destination.label,
                    style: TextStyle(
                      color: selected ? AppColors.violet : AppColors.muted,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.auto_awesome_outlined,
              size: 17,
              color: AppColors.violet,
            ),
            const SizedBox(width: 8),
            const Text(
              'Your ideas, ready to travel',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
}
