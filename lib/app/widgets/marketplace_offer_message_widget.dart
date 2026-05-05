import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:super_up/app/core/api_service/offer/offer_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class MarketplaceOfferMessageWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isMeSender;

  const MarketplaceOfferMessageWidget({
    super.key,
    required this.data,
    required this.isMeSender,
  });

  @override
  State<MarketplaceOfferMessageWidget> createState() =>
      _MarketplaceOfferMessageWidgetState();
}

class _MarketplaceOfferMessageWidgetState
    extends State<MarketplaceOfferMessageWidget> {
  bool _submitting = false;

  String get _roomId => (widget.data['_roomId'] ?? '').toString();
  String get _messageId => (widget.data['_messageId'] ?? '').toString();

  String get _status =>
      (widget.data['status'] ?? 'pending').toString().trim().toLowerCase();

  String get _currency =>
      (widget.data['currency'] ?? 'KES').toString().trim().isEmpty
          ? 'KES'
          : (widget.data['currency'] ?? 'KES').toString().trim();

  num? get _amount {
    final v = widget.data['amount'];
    if (v is num) return v;
    return num.tryParse((v ?? '').toString());
  }

  String _formatMoney(num? value) {
    if (value == null) return '';
    final f = NumberFormat('#,##0', 'en_KE');
    return '$_currency ${f.format(value)}';
  }

  bool get _canRespond {
    if (widget.isMeSender) return false;
    if (_status == 'accepted' || _status == 'declined') return false;
    return _roomId.isNotEmpty && _messageId.isNotEmpty;
  }

  Future<void> _respond(String status) async {
    if (!_canRespond) return;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await OfferApiService.I.respond(
        roomId: _roomId,
        messageId: _messageId,
        status: status,
      );
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<num?> _askAmount(BuildContext context, {required String title}) async {
    final c = TextEditingController();
    final res = await showCupertinoDialog<num?>(
      context: context,
      builder: (_) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CupertinoTextField(
              controller: c,
              placeholder: 'Amount',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                final n = num.tryParse(c.text.trim());
                Navigator.pop(context, n);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    return res;
  }

  Future<void> _sendNewOffer({
    required num amount,
    required String? relatedTo,
  }) async {
    if (_roomId.isEmpty) return;
    final payload = <String, dynamic>{
      'type': 'marketplace_offer',
      'amount': amount,
      'currency': _currency,
      'status': 'pending',
      if (relatedTo != null && relatedTo.trim().isNotEmpty) 'relatedTo': relatedTo,
    };

    final localMsg = VCustomMessage.buildMessage(
      roomId: _roomId,
      data: VCustomMsgData(data: payload),
      content: 'Offer: ${_formatMoney(amount)}',
    );

    await VChatController.I.nativeApi.local.message.insertMessage(localMsg);
    VMessageUploaderQueue.instance.addToQueue(
      await MessageFactory.createUploadMessage(localMsg),
    );
  }

  Future<void> _counter() async {
    if (!_canRespond) return;
    final amt = await _askAmount(context, title: 'Counter offer');
    if (amt == null) return;
    await _respond('countered');
    try {
      await _sendNewOffer(amount: amt, relatedTo: _messageId);
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: e.toString());
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'accepted':
        return const Color(0xFF2E7D32);
      case 'declined':
        return const Color(0xFFC62828);
      case 'countered':
        return const Color(0xFFB48648);
      default:
        return const Color(0xFF6D6D6D);
    }
  }

  String _statusLabel() {
    switch (_status) {
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'countered':
        return 'Countered';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final amt = _amount;
    final money = _formatMoney(amt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Offer',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor().withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _statusColor().withOpacity(0.35)),
              ),
              child: Text(
                _statusLabel(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          money.isEmpty ? 'Offer' : money,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (_canRespond) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFF2E7D32),
                  onPressed: _submitting ? null : () => _respond('accepted'),
                  child: _submitting
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : const Text(
                          'Accept',
                          style: TextStyle(color: CupertinoColors.white),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFFB48648),
                  onPressed: _submitting ? null : _counter,
                  child: const Text(
                    'Counter',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFFC62828),
                  onPressed: _submitting ? null : () => _respond('declined'),
                  child: const Text(
                    'Decline',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
