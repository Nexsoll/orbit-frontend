import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/modules/tickets/services/tickets_api_service.dart';
import 'package:super_up/app/modules/tickets/views/ticket_detail_view.dart';
import 'package:super_up_core/super_up_core.dart';

class TicketShareMessageWidget extends StatefulWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const TicketShareMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  @override
  State<TicketShareMessageWidget> createState() =>
      _TicketShareMessageWidgetState();
}

class _TicketShareMessageWidgetState extends State<TicketShareMessageWidget> {
  static const _brand = Color(0xFFB48648);

  late final TicketsApiService _api;
  Map<String, dynamic>? _ticket;
  bool _loading = false;
  bool _buying = false;

  Map<String, dynamic> get _data => _ticket ?? widget.data;

  String get _ticketId =>
      (_data['ticketId'] ?? _data['_id'] ?? _data['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<TicketsApiService>();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    if (_ticketId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final ticket = await _api.getTicket(_ticketId);
      if (mounted) setState(() => _ticket = ticket);
    } catch (_) {
      // Keep the shared payload visible when the ticket no longer loads.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _priceOf(Map<String, dynamic> t) {
    final raw = t['priceKes'] ?? 0;
    return raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
  }

  int _remainingOf(Map<String, dynamic> t) {
    final raw = t['remaining'] ?? 0;
    return raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
  }

  bool _isOwner(Map<String, dynamic> t) {
    final uploaderId = (t['uploaderId'] ?? '').toString();
    return uploaderId.isNotEmpty && uploaderId == AppAuth.myId;
  }

  bool _isExpired(Map<String, dynamic> t) {
    try {
      final raw = t['expiryDate'];
      if (raw == null) return false;
      final date = raw is String ? DateTime.parse(raw) : raw as DateTime;
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final date = raw is String ? DateTime.parse(raw) : raw as DateTime;
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  Future<void> _buyTicket() async {
    final id = _ticketId;
    if (id.isEmpty || _buying) return;

    final ticket = _data;
    final price = _priceOf(ticket);
    if (BalanceService.instance.balance < price) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Insufficient balance. Please top up your wallet.',
      );
      return;
    }

    final name = (ticket['name'] ?? 'Ticket').toString();
    final confirm = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Buy Ticket',
      content: 'Buy "$name" for KES ${price.toStringAsFixed(0)}?',
    );
    if (confirm != 1) return;

    setState(() => _buying = true);
    VAppAlert.showLoading(context: context);
    try {
      await _api.buyTicket(id);
      await BalanceService.instance.init();
      final updated = await _api.getTicket(id);
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _ticket = updated);
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Ticket purchased',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _data;
    final name = (ticket['name'] ?? 'Ticket').toString();
    final imageUrl = (ticket['imageUrl'] ?? '').toString();
    final hasImage = ticket['hasImage'] == true || imageUrl.isNotEmpty;
    final isSold = ticket['isSold'] == true;
    final isBuyer = ticket['isBuyer'] == true;
    final isOwner = _isOwner(ticket);
    final imageBlurred = (ticket['imageBlurred'] == true || !isOwner) && hasImage;
    final isExpired = _isExpired(ticket);
    final remaining = _remainingOf(ticket);
    final category = (ticket['category'] ?? '').toString();
    final uploaderName = (ticket['uploaderName'] ?? '').toString();
    final price = _priceOf(ticket);
    final canBuy = !isOwner && !isBuyer && !isSold && !isExpired;

    return GestureDetector(
      onTap: () async {
        final id = _ticketId;
        if (id.isNotEmpty) {
          await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => TicketDetailView(
                ticketId: id,
                initialTicket: ticket,
              ),
            ),
          );
          _loadTicket();
        }
      },
      child: Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brand.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.ticket, size: 14, color: _brand),
              const SizedBox(width: 4),
              const Text(
                'Shared a Ticket',
                style: TextStyle(
                  color: _brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (_loading)
                const CupertinoActivityIndicator(radius: 6),
            ],
          ),
          const SizedBox(height: 8),
          if (hasImage) _buildImage(imageUrl, imageBlurred),
          if (hasImage) const SizedBox(height: 8),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('KES ${price.toStringAsFixed(0)}', CupertinoIcons.money_dollar),
              if (category.isNotEmpty) _chip(category, CupertinoIcons.tag),
              if (remaining > 0) _chip('$remaining left', CupertinoIcons.number),
              if (_formatDate(ticket['expiryDate']).isNotEmpty)
                _chip(
                  'Exp: ${_formatDate(ticket['expiryDate'])}',
                  CupertinoIcons.calendar,
                ),
            ],
          ),
          if (uploaderName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              uploaderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (isBuyer)
                _status('Purchased', const Color(0xFF10B981))
              else if (isSold)
                _status('Sold', Colors.grey.shade500)
              else if (isExpired)
                _status('Expired', CupertinoColors.destructiveRed),
              const Spacer(),
              if (canBuy)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minSize: 0,
                  color: _brand,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _buying ? null : _buyTicket,
                  child: _buying
                      ? const CupertinoActivityIndicator(
                          radius: 7,
                          color: CupertinoColors.white,
                        )
                      : const Text(
                          'Buy',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildImage(String imageUrl, bool blurred) {
    if (imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: _brand.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(CupertinoIcons.ticket, color: _brand),
      );
    }

    Widget image = Image.network(
      imageUrl,
      width: double.infinity,
      height: 120,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: double.infinity,
        height: 120,
        color: _brand.withOpacity(0.1),
        child: const Icon(CupertinoIcons.photo, color: _brand),
      ),
    );

    if (blurred) {
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: image,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          image,
          if (blurred)
            Container(
              width: double.infinity,
              height: 120,
              color: Colors.black.withOpacity(0.32),
              child: const Center(
                child: Icon(
                  CupertinoIcons.lock,
                  color: CupertinoColors.white,
                  size: 30,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _brand),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _status(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
