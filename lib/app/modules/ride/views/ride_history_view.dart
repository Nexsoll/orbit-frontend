import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RideHistoryView extends StatefulWidget {
  final bool isDriver; // true => fetch as driver, false => as passenger
  const RideHistoryView({super.key, required this.isDriver});

  @override
  State<RideHistoryView> createState() => _RideHistoryViewState();
}

class _RideHistoryViewState extends State<RideHistoryView> {
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
      final list = await DriversApiService.rideHistory(role: widget.isDriver ? 'driver' : 'passenger');
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

  String? _absImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('file://')) {
      final trimmed = url.substring('file://'.length);
      final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      final baseOrigin = '${SConstants.sApiBaseUrl.scheme}://${SConstants.sApiBaseUrl.authority}';
      return '$baseOrigin$normalized';
    }
    final baseOrigin = '${SConstants.sApiBaseUrl.scheme}://${SConstants.sApiBaseUrl.authority}';
    final path = url.startsWith('/') ? url : '/$url';
    return '$baseOrigin$path';
  }

  Future<void> _exportPdf() async {
    try {
      final doc = pw.Document();
      final df = DateFormat('yyyy-MM-dd HH:mm');

      doc.addPage(
        pw.MultiPage(
          pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
          build: (ctx) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ride History', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text(widget.isDriver ? 'Driver' : 'Passenger'),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(80), // date
                  1: const pw.FlexColumnWidth(2), // pickup
                  2: const pw.FlexColumnWidth(2), // drop
                  3: const pw.FixedColumnWidth(55), // fare
                  4: const pw.FixedColumnWidth(70), // status
                  5: const pw.FlexColumnWidth(1.5), // counterpart
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pickup')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Drop-off')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('KES')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Status')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(widget.isDriver ? 'Passenger' : 'Driver')),
                    ],
                  ),
                  ..._items.map((r) {
                    final createdAt = r['createdAt']?.toString();
                    final dt = createdAt != null ? DateTime.tryParse(createdAt) : null;
                    final status = (r['status'] ?? '').toString();
                    final fare = (r['fareKes'] as num?)?.toStringAsFixed(0) ?? '-';
                    final pickup = (r['pickupAddress'] ?? '').toString();
                    final drop = (r['dropoffAddress'] ?? '').toString();
                    final counterpart = widget.isDriver ? (r['passenger'] as Map<String, dynamic>?) : (r['driver'] as Map<String, dynamic>?);
                    final name = counterpart != null ? (counterpart['fullName'] ?? '') as String : '';
                    return pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(dt != null ? df.format(dt) : '-')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(pickup, maxLines: 2)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(drop, maxLines: 2)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fare)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(status.toUpperCase())),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(name)),
                    ]);
                  }),
                ],
              )
            ];
          },
        ),
      );

      final Uint8List bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'ride_history_${widget.isDriver ? 'driver' : 'passenger'}.pdf');
    } catch (_) {}
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    Color color;
    if (lower == 'completed') color = const Color(0xFF22C55E);
    else if (lower == 'canceled') color = const Color(0xFFEF4444);
    else color = Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Ride History'),
        trailing: CupertinoButton(
          padding: const EdgeInsets.all(8),
          onPressed: _items.isEmpty ? null : _exportPdf,
          child: const Icon(CupertinoIcons.square_arrow_up, color: Color(0xFFB48648)),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _items.isEmpty
                ? const Center(child: Text('No history'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final r = _items[i];
                      final status = (r['status'] ?? '').toString();
                      final fare = (r['fareKes'] as num?)?.toDouble() ?? 0;
                      final pickup = (r['pickupAddress'] ?? '').toString();
                      final drop = (r['dropoffAddress'] ?? '').toString();
                      final dtStr = r['createdAt']?.toString();
                      final dt = dtStr != null ? DateTime.tryParse(dtStr) : null;
                      final df = DateFormat('MMM d, HH:mm');
                      final counterpart = widget.isDriver ? (r['passenger'] as Map<String, dynamic>?) : (r['driver'] as Map<String, dynamic>?);
                      final name = counterpart != null ? (counterpart['fullName'] ?? '') as String : '';
                      final avatarUrl = counterpart != null ? _absImageUrl((counterpart['userImage'] ?? '') as String?) : null;
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
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                                  child: (avatarUrl == null || avatarUrl.isEmpty) ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?') : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name.isEmpty ? (widget.isDriver ? 'Passenger' : 'Driver') : name,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      if (dt != null)
                                        Text(df.format(dt), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('KES ${fare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                _statusChip(status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(children: const [
                              Icon(CupertinoIcons.location_solid, size: 18, color: Color(0xFF3B82F6)),
                              SizedBox(width: 8),
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(left: 26),
                              child: Text(pickup, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(height: 6),
                            Row(children: const [
                              Icon(CupertinoIcons.map_pin_ellipse, size: 18, color: Color(0xFF22C55E)),
                              SizedBox(width: 8),
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(left: 26),
                              child: Text(drop, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
