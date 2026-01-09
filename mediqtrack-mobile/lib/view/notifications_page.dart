import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mediqtrack03/services/api_service.dart';
import 'package:mediqtrack03/services/notification_event.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = false;
  int? _patientId;

  @override
  void initState() {
    super.initState();
    _load();
    NotificationEventBus.tick.addListener(_onNotificationPing);
  }

  void _onNotificationPing() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _all = []);
        return;
      }
      final pid = await ApiService.syncUser(user.uid, user.email ?? 'user@example.com');
      if (pid == null) {
        setState(() => _all = []);
        return;
      }
      _patientId = pid;

      final list = await ApiService.fetchNotifications(pid);
      setState(() {
        _all = list
            .map((a) => _AlertItem(
                  id: a.id.toString(),
                  title: a.title,
                  body: a.body ?? '',
                  type: _mapType(a.type),
                  time: a.createdAt,
                  read: a.isRead,
                ))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  List<_AlertItem> _all = [];

  FilterType _filter = FilterType.all;

  Future<void> _onRefresh() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(_all, _filter);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            title: const Text('Alerts', style: TextStyle(color: Colors.white)),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Mark all as read',
                onPressed: () {
                  setState(() {
                    for (final n in _all) {
                      n.read = true;
                    }
                  });
                },
                icon: const Icon(Icons.done_all),
              ),
            ],
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('All', FilterType.all),
                  _chip('Unread', FilterType.unread),
                  _chip('Read', FilterType.read),
                ],
              ),
            ),
          ),

          // Info bar (count)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${filtered.length} alert${filtered.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _all.isEmpty
                        ? null
                        : () async {
                            final unread = _all.where((n) => !n.read).toList();
                            for (final item in unread) {
                              final id = int.tryParse(item.id);
                              if (id != null) {
                                await ApiService.markNotificationRead(id);
                              }
                            }
                            if (mounted) {
                              setState(() {
                                for (final n in _all) {
                                  n.read = true;
                                }
                              });
                            }
                          },
                    child: const Text('Read All'),
                  ),
                ],
              ),
            ),
          ),

          if (filtered.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyState(),
            )
          else
            SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    background: _dismissBg(),
                    onDismissed: (_) async {
                      final id = int.tryParse(item.id);
                      if (id != null) {
                        await ApiService.deleteNotification(id);
                      }
                      setState(() {
                        _all.removeWhere((e) => e.id == item.id);
                      });
                    },
                    child: _AlertTile(
                      item: item,
                      onToggleRead: () async {
                        final id = int.tryParse(item.id);
                        if (id != null && !item.read) {
                          await ApiService.markNotificationRead(id);
                        }
                        setState(() {
                          item.read = true;
                        });
                      },
                      onOpen: () {
                        // TODO: Navigate to detail if needed
                        // e.g., go to My Queue when type == queue
                      },
                    ),
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _chip(String label, FilterType type) {
    final selected = _filter == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = type),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }

  static List<_AlertItem> _applyFilter(List<_AlertItem> src, FilterType f) {
    final cutoff = DateTime.now().subtract(const Duration(days: 3));
    final recent = src.where((e) => e.time.isAfter(cutoff)).toList();
    switch (f) {
      case FilterType.all:
        return List.of(recent);
      case FilterType.unread:
        return recent.where((e) => !e.read).toList();
      case FilterType.read:
        return recent.where((e) => e.read).toList();
    }
  }

  Widget _dismissBg() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Icon(Icons.delete_outline, color: Colors.red.shade700),
    );
  }

  AlertType _mapType(String t) {
    switch (t.toLowerCase()) {
      case 'queue':
        return AlertType.queue;
      case 'success':
        return AlertType.success;
      case 'warning':
        return AlertType.warning;
      case 'error':
        return AlertType.error;
      default:
        return AlertType.system;
    }
  }
}

// ====== Tile ======

class _AlertTile extends StatelessWidget {
  final _AlertItem item;
  final VoidCallback onToggleRead;
  final VoidCallback onOpen;

  const _AlertTile({
    required this.item,
    required this.onToggleRead,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(item.type);
    final iconColor = _iconColorFor(context, item.type);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          color: item.read
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surface.withOpacity(0.92),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: iconColor.withOpacity(0.15),
                  child: Icon(iconData, color: iconColor),
                ),
                if (!item.read)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: item.read
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(item.time),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(AlertType t) {
    switch (t) {
      case AlertType.system:
        return Icons.campaign_outlined;
      case AlertType.queue:
        return Icons.notifications_active_outlined;
      case AlertType.success:
        return Icons.check_circle_outline;
      case AlertType.warning:
        return Icons.warning_amber_outlined;
      case AlertType.error:
        return Icons.error_outline;
    }
  }

  static Color _iconColorFor(BuildContext context, AlertType t) {
    final cs = Theme.of(context).colorScheme;
    switch (t) {
      case AlertType.system:
        return cs.primary;
      case AlertType.queue:
        return cs.secondary;
      case AlertType.success:
        return Colors.green;
      case AlertType.warning:
        return Colors.orange;
      case AlertType.error:
        return Colors.red;
    }
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
    // For production, use intl package for proper formatting.
  }

}

// ====== Empty state ======

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(
            'No alerts yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'New alerts about your queue and clinic announcements will appear here.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ====== Models & Filters ======

enum AlertType { system, queue, success, warning, error }
enum FilterType { all, unread, read }

class _AlertItem {
  final String id;
  final String title;
  final String body;
  final AlertType type;
  final DateTime time;
  bool read;

  _AlertItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.time,
    this.read = false,
  });
}
