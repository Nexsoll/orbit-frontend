import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';

class ScheduledRidesView extends StatefulWidget {
  const ScheduledRidesView({super.key});

  @override
  State<ScheduledRidesView> createState() => _ScheduledRidesViewState();
}

class _ScheduledRidesViewState extends State<ScheduledRidesView> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await DriversApiService.getScheduledRides();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String id) async {
    await DriversApiService.cancelScheduledRide(id);
    await _load();
  }

  Future<void> _edit(String id, DateTime initial) async {
    DateTime temp = initial.isAfter(DateTime.now().add(const Duration(minutes: 10)))
        ? initial
        : DateTime.now().add(const Duration(minutes: 15));
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Reschedule'),
        message: SizedBox(
          height: 220,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.dateAndTime,
            minimumDate: DateTime.now().add(const Duration(minutes: 5)),
            initialDateTime: temp,
            use24hFormat: true,
            onDateTimeChanged: (v) => temp = v,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await DriversApiService.rescheduleScheduledRide(id: id, scheduledAtIso: temp.toIso8601String());
              if (mounted) await _load();
            },
            child: const Text('Save'),
          )
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Scheduled Rides')),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _items.isEmpty
                ? const Center(child: Text('No scheduled rides'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final r = _items[i];
                      final df = DateFormat('MMM d, HH:mm');
                      final dtStr = r['scheduledAt']?.toString();
                      final dt = dtStr != null ? DateTime.tryParse(dtStr) : null;
                      final fare = (r['fareKes'] as num?)?.toDouble() ?? 0;
                      final pc = (r['passengersCount'] as num?)?.toInt() ?? 1;
                      final status = (r['status'] ?? '').toString();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dt != null ? 'Scheduled: ${df.format(dt)}' : 'Scheduled',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text('KES ${fare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(CupertinoIcons.person_2_fill, size: 18, color: Color(0xFFB48648)),
                                const SizedBox(width: 8),
                                Text(
                                  '$pc passenger${pc == 1 ? '' : 's'}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(children: const [
                              Icon(CupertinoIcons.location_solid, size: 18, color: Color(0xFF3B82F6)),
                              SizedBox(width: 8),
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(left: 26),
                              child: Text((r['pickupAddress'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(height: 6),
                            Row(children: const [
                              Icon(CupertinoIcons.map_pin_ellipse, size: 18, color: Color(0xFF22C55E)),
                              SizedBox(width: 8),
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(left: 26),
                              child: Text((r['dropoffAddress'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(status, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
                                ),
                                const Spacer(),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  color: const Color(0xFF3B82F6),
                                  onPressed: (status == 'canceled')
                                      ? null
                                      : () => _edit((r['id'] ?? '').toString(), dt ?? DateTime.now().add(const Duration(minutes: 15))),
                                  child: const Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  color: const Color(0xFFEF4444),
                                  onPressed: status == 'canceled' ? null : () => _cancel((r['id'] ?? '').toString()),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                )
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
