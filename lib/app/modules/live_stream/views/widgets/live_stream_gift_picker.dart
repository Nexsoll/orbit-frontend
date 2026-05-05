// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get_it/get_it.dart';
import '../../services/live_stream_api_service.dart';

import '../../controllers/live_stream_chat_controller.dart';

class LiveStreamGiftPicker extends StatefulWidget {
  final LiveStreamChatController chatController;

  const LiveStreamGiftPicker({
    super.key,
    required this.chatController,
  });

  @override
  State<LiveStreamGiftPicker> createState() => _LiveStreamGiftPickerState();
}

class _LiveStreamGiftPickerState extends State<LiveStreamGiftPicker> {
  List<Gift> _gifts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Make direct HTTP call to get gifts (same as chat implementation)
      final url = Uri.parse('${SConstants.sApiBaseUrl}/gifts');

      // Add authorization header
      final accessToken =
          VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['code'] == 2000 && jsonData['data'] is List) {
          final giftsData = jsonData['data'] as List;
          final gifts =
              giftsData.map((giftJson) => Gift.fromMap(giftJson)).toList();

          if (mounted) {
            setState(() {
              _gifts = gifts;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _error = 'No gifts available or invalid response';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load gifts: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.gift,
                  color: Colors.purple,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Send Gift',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading gifts',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGifts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_gifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.gift,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No gifts available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _gifts.length,
      itemBuilder: (context, index) {
        final gift = _gifts[index];
        return _buildGiftItem(gift);
      },
    );
  }

  Widget _buildGiftItem(Gift gift) {
    return GestureDetector(
      onTap: () => _onGiftSelected(gift),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _getFullImageUrl(gift.imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.gift,
                              color: Colors.grey,
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Gift',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
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
            ),
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Text(
                    'KSh ${gift.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFullImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    return '${SConstants.baseMediaUrl}$imageUrl';
  }

  Future<void> _onGiftSelected(Gift gift) async {
    final streamId = widget.chatController.currentStreamId;
    if (streamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stream not ready. Please try again.')),
      );
      return;
    }

    try {
      // Ask for user's M-Pesa phone number
      final phone = await _promptPhoneNumber();
      if (phone == null || phone.isEmpty) return;

      // Initiate STK push for this gift
      final api = GetIt.I.get<LiveStreamApiService>();

      // Show processing dialog
      bool dismissed = false;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WillPopScope(
          onWillPop: () async => false,
          child: const AlertDialog(
            content: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 8),
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 16),
                  Expanded(child: Text('Sending STK push...')),
                ],
              ),
            ),
          ),
        ),
      ).then((_) => dismissed = true);

      await api.initiateGiftPurchase(
        streamId: streamId,
        giftId: gift.id,
        phone: phone,
      );

      // Update dialog text to waiting for confirmation
      if (!dismissed) {
        Navigator.of(context).pop();
      }
      dismissed = false;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(width: 8),
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 16),
                  Expanded(child: Text('Please confirm payment on your phone...')),
                ],
              ),
            ),
          ),
        ),
      ).then((_) => dismissed = true);

      // Poll status until success/failure (up to ~2 minutes)
      final started = DateTime.now();
      String status = 'pending';
      while (DateTime.now().difference(started).inSeconds < 120) {
        await Future.delayed(const Duration(seconds: 2));
        final st = await api.getGiftPurchaseStatus(streamId: streamId, giftId: gift.id);
        status = (st['status'] as String?) ?? 'pending';
        if (status != 'pending') break;
      }

      // Close waiting dialog
      if (!dismissed && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (status == 'success') {
        // Send gift message (server will verify and consume purchase, and credit host)
        await widget.chatController.sendGift(
          giftId: gift.id,
          giftName: gift.name ?? 'Gift',
          giftImage: gift.imageUrl,
          giftPrice: gift.price,
        );

        // Close the gift picker
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gift sent! KSh ${gift.price.toStringAsFixed(0)}'),
              backgroundColor: Colors.purple,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show failure/cancel/timeout
        final reason = status == 'failed'
            ? 'Payment failed'
            : status == 'cancelled'
                ? 'Payment cancelled'
                : status == 'timeout'
                    ? 'Payment timed out'
                    : 'Payment pending';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not complete purchase: $reason'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close the processing dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send gift: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _promptPhoneNumber() async {
    final controller = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter M-Pesa phone'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: false),
          decoration: const InputDecoration(
            hintText: '07XXXXXXXX or 2547XXXXXXXX',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              result = controller.text.trim();
              Navigator.of(ctx).pop();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result;
  }
}
