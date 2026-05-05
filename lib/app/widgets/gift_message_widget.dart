// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/core/services/claimed_gifts_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class GiftMessageWidget extends StatefulWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const GiftMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  @override
  State<GiftMessageWidget> createState() => _GiftMessageWidgetState();
}

class _GiftMessageWidgetState extends State<GiftMessageWidget> {
  bool _isClaimed = false;

  @override
  void initState() {
    super.initState();
    _checkClaimedStatus();
  }

  /// Create a unique identifier for this gift message
  String _getGiftMessageId() {
    final messageId = widget.data['messageId'] as String?;
    final myUserId = VAppConstants.myProfile.id;

    // Use the messageId from the gift data if available, otherwise fallback to a combination
    if (messageId != null) {
      return '${myUserId}_$messageId';
    }

    // Fallback for older messages without messageId
    final giftId = widget.data['giftId'] as String?;
    final price = widget.data['price'] as num?;
    return '${myUserId}_${giftId}_${price?.toString() ?? '0'}';
  }

  /// Check if this gift has already been claimed
  Future<void> _checkClaimedStatus() async {
    final messageId = _getGiftMessageId();
    final isClaimed =
        await ClaimedGiftsService.instance.isGiftClaimed(messageId);
    if (mounted) {
      setState(() {
        _isClaimed = isClaimed;
      });
    }
  }

  String _getFullImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl; // Already a full URL
    }
    // Construct full URL: baseMediaUrl + imageUrl
    return '${SConstants.baseMediaUrl}$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    final giftId = widget.data['giftId'] as String?;
    final imageUrl = widget.data['imageUrl'] as String?;
    final price = widget.data['price'] as num?;

    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gift image
          if (imageUrl != null && imageUrl.isNotEmpty)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _getFullImageUrl(imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            color: Colors.grey,
                            size: 32,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Gift',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Gift price
          if (price != null)
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade600,
              ),
            ),

          // Claim button (only for receiver)
          if (!widget.isMeSender) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isClaimed
                  ? null
                  : () {
                      _onClaimGift(context, giftId, price);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isClaimed ? Colors.grey : Colors.green.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _isClaimed ? 'Claimed' : 'Claim',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onClaimGift(BuildContext context, String? giftId, num? price) {
    if (giftId == null || price == null) return;

    // Show a simple dialog for now
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim Gift'),
        content: Text(
            'You are about to claim a gift worth \$${price.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                // Claim gift using the new service method
                final messageId = _getGiftMessageId();
                final response = await ClaimedGiftsService.instance
                    .claimGift(messageId, price.toDouble());

                // Update balance directly from response
                if (response['balance'] != null) {
                  BalanceService.instance.updateBalanceFromResponse(
                      (response['balance'] as num).toDouble());
                }

                // Update claimed state
                setState(() {
                  _isClaimed = true;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(response['message'] ??
                        'Gift of \$${price.toStringAsFixed(2)} claimed! New balance: ${response['formattedBalance'] ?? BalanceService.instance.formattedBalance}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to claim gift: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }
}
