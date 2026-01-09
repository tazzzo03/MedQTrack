import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class VisitHistoryPage extends StatefulWidget {
  const VisitHistoryPage({super.key});

  @override
  State<VisitHistoryPage> createState() => _VisitHistoryPageState();
}

class _VisitHistoryPageState extends State<VisitHistoryPage> {
  VisitFilter _filter = VisitFilter.all;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // Tukar ikut IP PC kau, contoh 10.82.145.75
  static const _apiBase = 'http://10.82.145.75:8000';

  late Future<List<VisitItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchHistory();
  }

  Future<List<VisitItem>> _fetchHistory() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final uri = Uri.parse('$_apiBase/api/visit-history?firebase_uid=$uid');

    final res = await http.get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Failed to load history (${res.statusCode})');
    }
    final json = jsonDecode(res.body);
    if (json is! Map || json['success'] != true) {
      throw Exception(json is Map && json['message'] != null
          ? json['message']
          : 'Unexpected API response');
    }

    final List list = json['data'] as List;
    final items = list.map((e) => VisitItem.fromJson(e)).toList();
    items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit History', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<VisitItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = _fetchHistory()),
            );
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => setState(() => _future = _fetchHistory()),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: const [
                  _EmptyHistory(),
                ],
              ),
            );
          }
          final filtered = _applyFilter(items);
          final visible = filtered.take(15).toList();

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _fetchHistory()),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: visible.isEmpty ? 2 : visible.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _filterChips();
                }
                if (visible.isEmpty) {
                  return const _EmptyHistory();
                }
                final it = visible[i - 1];
                final statusColor = _statusColor(it.status);
                final icon = _statusIcon(it.status);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.15),
                        child: Icon(icon, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Queue No: ${it.queueNumber}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _MetaItem(
                                  icon: Icons.calendar_month_outlined,
                                  text: it.dateLabel,
                                ),
                                _MetaItem(
                                  icon: Icons.access_time_outlined,
                                  text: it.timeLabel,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (it.doctorName != null &&
                                it.doctorName!.isNotEmpty)
                              Text(
                                _doctorDisplayName(it.doctorName!),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            it.status,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'missed':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }


  Widget _filterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _chip('All', VisitFilter.all),
        _chip('Week', VisitFilter.week),
        _chip('Month', VisitFilter.month),
        if (_filter == VisitFilter.month)
          OutlinedButton.icon(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(_formatMonth(_selectedMonth)),
          ),
      ],
    );
  }

  Widget _chip(String label, VisitFilter type) {
    final selected = _filter == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = type),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
    );
  }

  List<VisitItem> _applyFilter(List<VisitItem> items) {
    final now = DateTime.now();
    switch (_filter) {
      case VisitFilter.all:
        return List.of(items);
      case VisitFilter.week:
        final cutoff = now.subtract(const Duration(days: 7));
        return items.where((e) => e.sortDate.isAfter(cutoff)).toList();
      case VisitFilter.month:
        return items
            .where((e) =>
                e.sortDate.year == _selectedMonth.year &&
                e.sortDate.month == _selectedMonth.month)
            .toList();
    }
  }

  String _doctorDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.toLowerCase().startsWith('dr')) return trimmed;
    return 'Dr. $trimmed';
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final years = List.generate(5, (i) => now.year - i);
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Month'),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      value: selectedMonth,
                      isExpanded: true,
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_monthLabel(i + 1)),
                        ),
                      ),
                      onChanged: (v) {
                        if (v == null) return;
                        setStateDialog(() => selectedMonth = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<int>(
                      value: selectedYear,
                      isExpanded: true,
                      items: years
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setStateDialog(() => selectedYear = v);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                      context, DateTime(selectedYear, selectedMonth)),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedMonth = picked);
    }
  }

  String _formatMonth(DateTime dt) {
    return '${_monthLabel(dt.month)} ${dt.year}';
  }

  String _monthLabel(int m) {
    return const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][m - 1];
  }
  static IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'missed':
        return Icons.warning_amber_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.history;
    }
  }
}

class VisitItem {
  final String queueNumber;
  final String status;
  final int? roomId;
  final String? roomName;
  final String? doctorName;
  final String? clinicName;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  VisitItem({
    required this.queueNumber,
    required this.status,
    this.roomId,
    this.roomName,
    this.doctorName,
    this.clinicName,
    this.updatedAt,
    this.createdAt,
  });

  factory VisitItem.fromJson(Map<String, dynamic> j) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return VisitItem(
      queueNumber: j['queue_number']?.toString() ?? '-',
      status: j['status']?.toString() ?? '-',
      roomId: j['room_id'] as int?,
      roomName: j['room_name']?.toString(),
      doctorName: j['doctor_name']?.toString(),
      clinicName: j['clinic_name']?.toString(),
      updatedAt: parseDt(j['updated_at']),
      createdAt: parseDt(j['created_at']),
    );
  }

  String get roomLabel {
    if (roomName != null && roomName!.isNotEmpty) return roomName!;
    if (roomId != null) return 'Room $roomId';
    return '-';
    }

  String get roomLine {
    final room = roomLabel;
    if (doctorName != null && doctorName!.isNotEmpty) {
      return '$room - Dr. $doctorName';
    }
    return room;
  }

  DateTime get sortDate {
    return updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get dateLabel {
    final dt = updatedAt ?? createdAt;
    if (dt == null) return '-';
    return '${_pad(dt.day)} ${_month(dt.month)} ${dt.year}';
  }

  String get timeLabel {
    final dt = updatedAt ?? createdAt;
    if (dt == null) return '-';
    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = _pad(dt.minute);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
  static String _month(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_outlined,
                size: 64, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            Text(
              'No visit history yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Your past clinic visits will appear here once you complete a queue.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}


enum VisitFilter { all, week, month }
