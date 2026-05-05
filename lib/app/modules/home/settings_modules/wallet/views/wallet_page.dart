// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with WidgetsBindingObserver {
  final _amountCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  bool _loading = false;
  bool _isWithdraw = false;
  List<Map<String, dynamic>>? _history;
  bool _historyLoading = false;

  // PesaPal pending verification
  String? _pendingOrderTrackingId;
  String? _pendingRedirectUrl;
  bool _isPesapalVerifyDialogOpen = false;
  bool _pesapalVerifying = false;

  String _extractBackendMessage(String body) {
    try {
      final parsed = json.decode(body) as Map<String, dynamic>;
      final m = parsed['message']?.toString().trim();
      if (m != null && m.isNotEmpty) return m;
      final d = parsed['data']?.toString().trim();
      if (d != null && d.isNotEmpty) return d;
      return 'Request failed';
    } catch (_) {
      return 'Request failed';
    }
  }

  Future<void> _showErrorDialog(String message) async {
    final m = message.trim().isEmpty ? 'Request failed' : message.trim();
    try {
      await VAppAlert.showOkAlertDialog(
          context: context, title: 'Error', content: m);
    } catch (_) {
      // ignore
    }
  }

  void _hideAnyLoadingDialog() {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {
      // ignore
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Always refresh balance when opening wallet
    BalanceService.instance.init();
    _loadHistory();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyPendingPesapalPayment();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = BalanceService.instance.balance;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Wallet'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFB48648),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'KSh ${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: _loading ? null : _onTopUpPressed,
                      child: const Text(
                        'Top up',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: CupertinoSlidingSegmentedControl<bool>(
                groupValue: _isWithdraw,
                onValueChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _isWithdraw = val;
                      _amountCtrl.clear();
                      _accountNumberCtrl.clear();
                    });
                  }
                },
                children: const {
                  false: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Top up'),
                  ),
                  true: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Withdraw'),
                  ),
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isWithdraw ? 'Withdraw from wallet' : 'Top up your wallet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_isWithdraw) ...[
              CupertinoTextField(
                controller: _accountNumberCtrl,
                placeholder: 'Phone / Account Number',
                keyboardType: TextInputType.phone,
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 12),
            ],
            CupertinoTextField(
              controller: _amountCtrl,
              placeholder: 'Amount (KES)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _loading ? null : (_isWithdraw ? _onWithdrawPressed : _onTopUpPressed),
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(_isWithdraw ? 'Withdraw' : 'Top up'),
            ),
            const SizedBox(height: 10),
            if (!_isWithdraw)
              const Text(
                'After you press Top up, a payment page will open for you to complete '
                'payment via M-Pesa, Visa, Mastercard, or other methods supported by PesaPal. '
                'Return to the app to verify and update your balance.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              )
            else
              const Text(
                'Withdrawal requests are sent to PesaPal for processing. Withdrawals '
                'may take some time to reflect in your account. Make sure to enter the correct account details.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent top-ups',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: _historyLoading ? null : _loadHistory,
                  icon: _historyLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (_history == null && !_historyLoading)
              const Text('No history yet',
                  style: TextStyle(color: Colors.black54))
            else if (_historyLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            else
              ..._history!.map((h) => _WalletHistoryItem(item: h)).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _onTopUpPressed() async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amountCtrl.text.trim());

    if (amount == null || amount <= 0) {
      await _showErrorDialog('Enter a valid amount');
      return;
    }

    setState(() => _loading = true);
    try {
      VAppAlert.showLoading(
          context: context, message: 'Initiating PesaPal payment...');
      final tx = await _initiatePesapalCheckout(amount: amount);
      _hideAnyLoadingDialog();
      if (tx == null) return;

      final redirectUrl = (tx['redirectUrl'] ?? '').toString();
      final orderTrackingId = (tx['orderTrackingId'] ?? '').toString();

      if (orderTrackingId.isEmpty) {
        await _showErrorDialog('Failed to start PesaPal payment');
        return;
      }

      if (redirectUrl.isNotEmpty) {
        final uri = Uri.tryParse(redirectUrl);
        if (uri != null) {
          final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          if (!ok) {
            final ok2 =
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!ok2) {
              await _showErrorDialog('Failed to open PesaPal payment page');
            }
          }
        } else {
          await _showErrorDialog('PesaPal payment URL is invalid');
        }
      } else {
        await _showErrorDialog('PesaPal payment URL is missing');
      }

      _pendingOrderTrackingId = orderTrackingId;
      _pendingRedirectUrl = redirectUrl;
      await _showPesapalVerifyDialog(orderTrackingId, redirectUrl: redirectUrl);
    } catch (e) {
      _hideAnyLoadingDialog();
      if (e is TimeoutException) {
        await _showErrorDialog(
            'Request timed out. Please check your internet and try again.');
      } else if (e.toString().contains('SocketException')) {
        await _showErrorDialog('No internet connection. Please try again.');
      } else {
        await _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onWithdrawPressed() async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amountCtrl.text.trim());
    final account = _accountNumberCtrl.text.trim();

    if (amount == null || amount <= 0) {
      await _showErrorDialog('Enter a valid amount');
      return;
    }
    if (account.isEmpty) {
      await _showErrorDialog('Enter your account number or phone');
      return;
    }

    setState(() => _loading = true);
    try {
      VAppAlert.showLoading(
          context: context, message: 'Initiating withdrawal...');
      await _requestWithdrawal(amount: amount, account: account);
      _hideAnyLoadingDialog();
      
      if (mounted) {
        VAppAlert.showSuccessSnackBar(
            message: 'Withdrawal request submitted', context: context);
      }
      
      // Update balance and history after withdrawal
      await BalanceService.instance.init();
      await _loadHistory();

      // Clear fields
      _amountCtrl.clear();
      _accountNumberCtrl.clear();

    } catch (e) {
      _hideAnyLoadingDialog();
      if (e is TimeoutException) {
        await _showErrorDialog(
            'Request timed out. Please check your internet and try again.');
      } else if (e.toString().contains('SocketException')) {
        await _showErrorDialog('No internet connection. Please try again.');
      } else {
        await _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestWithdrawal({required double amount, required String account}) async {
    final url = Uri.parse('${SConstants.sApiBaseUrl}/payments/pesapal/withdraw');
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw Exception('Login required. Please login again.');
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode({
      'amount': amount,
      'currency': 'KES',
      'accountNumber': account,
      'description': 'Wallet withdrawal',
    });
    final res = await http
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractBackendMessage(res.body));
    }

    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000 && (parsed['status'] as int?) != 200) {
        if (!parsed.containsKey('data')) {
             throw Exception((parsed['message'] ?? 'Failed to request withdrawal').toString());
        }
    }
  }


  Future<void> _verifyPendingPesapalPayment() async {
    if (!mounted) return;
    if (!_isPesapalVerifyDialogOpen) return;
    if (_pesapalVerifying) return;
    final trackingId = (_pendingOrderTrackingId ?? '').trim();
    if (trackingId.isEmpty) return;

    _pesapalVerifying = true;
    try {
      final data = await _verifyPesapalTransaction(trackingId);
      final status = (data?['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'success') {
        _pendingOrderTrackingId = null;
        _pendingRedirectUrl = null;
        if (_isPesapalVerifyDialogOpen) {
          _isPesapalVerifyDialogOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        await BalanceService.instance.init();
        await _loadHistory();
        if (mounted) {
          VAppAlert.showSuccessSnackBar(
              message: 'Top up successful', context: context);
        }
      }
    } catch (_) {
      // ignore
    } finally {
      _pesapalVerifying = false;
    }
  }

  /// Calls backend POST /api/v1/payments/pesapal/checkout
  Future<Map<String, dynamic>?> _initiatePesapalCheckout(
      {required double amount}) async {
    final url =
        Uri.parse('${SConstants.sApiBaseUrl}/payments/pesapal/checkout');
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw Exception('Login required. Please login again.');
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode({
      'amount': amount,
      'currency': 'KES',
      'description': 'Wallet top-up',
    });
    final res = await http
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractBackendMessage(res.body));
    }

    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      throw Exception(
          (parsed['message'] ?? 'Failed to start payment').toString());
    }

    return parsed['data'] as Map<String, dynamic>;
  }

  /// Calls backend GET /api/v1/payments/pesapal/verify/:orderTrackingId
  Future<Map<String, dynamic>?> _verifyPesapalTransaction(
      String orderTrackingId) async {
    try {
      final url = Uri.parse(
          '${SConstants.sApiBaseUrl}/payments/pesapal/verify/$orderTrackingId');
      final accessToken =
          VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };
      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final parsed = json.decode(res.body) as Map<String, dynamic>;
      if ((parsed['code'] as int?) != 2000) return null;
      return parsed['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showPesapalVerifyDialog(String orderTrackingId,
      {String? redirectUrl}) async {
    bool cancelled = false;
    _isPesapalVerifyDialogOpen = true;

    Timer? timer;
    bool inFlight = false;
    final startedAt = DateTime.now();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          timer ??= Timer.periodic(const Duration(seconds: 4), (_) async {
            if (cancelled) return;
            if (!mounted) return;
            if (inFlight) return;

            if (DateTime.now().difference(startedAt).inSeconds > 180) {
              cancelled = true;
              timer?.cancel();
              _isPesapalVerifyDialogOpen = false;
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              VAppAlert.showErrorSnackBar(
                  message: 'Verification timed out. Please tap Verify now.',
                  context: context);
              return;
            }

            inFlight = true;
            try {
              final data = await _verifyPesapalTransaction(orderTrackingId);
              final status =
                  (data?['status'] ?? '').toString().trim().toLowerCase();
              if (status == 'success') {
                cancelled = true;
                timer?.cancel();
                _pendingOrderTrackingId = null;
                _pendingRedirectUrl = null;
                _isPesapalVerifyDialogOpen = false;
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                await BalanceService.instance.init();
                await _loadHistory();
                if (mounted) {
                  VAppAlert.showSuccessSnackBar(
                      message: 'Top up successful', context: context);
                }
              }
            } finally {
              inFlight = false;
            }
          });
        });

        return AlertDialog(
          title: const Text('Complete Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text('Complete the payment in the opened PesaPal page...\n\n'
                  'You can pay via M-Pesa, Visa, Mastercard, and more.'),
            ],
          ),
          actions: [
            if (((redirectUrl ?? _pendingRedirectUrl) ?? '').trim().isNotEmpty)
              TextButton(
                onPressed: () async {
                  final toOpen = (redirectUrl ?? _pendingRedirectUrl)!.trim();
                  final uri = Uri.tryParse(toOpen);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                  }
                },
                child: const Text('Open again'),
              ),
            TextButton(
              onPressed: () async {
                if (cancelled) return;
                try {
                  final data = await _verifyPesapalTransaction(orderTrackingId);
                  final status =
                      (data?['status'] ?? '').toString().trim().toLowerCase();
                  if (status == 'success') {
                    _pendingOrderTrackingId = null;
                    _pendingRedirectUrl = null;
                    _isPesapalVerifyDialogOpen = false;
                    if (context.mounted) Navigator.of(ctx).pop();
                    await BalanceService.instance.init();
                    await _loadHistory();
                    if (mounted) {
                      VAppAlert.showSuccessSnackBar(
                          message: 'Top up successful', context: context);
                    }
                    return;
                  }
                  VAppAlert.showErrorSnackBar(
                      message: 'Payment not completed yet', context: context);
                } catch (e) {
                  await _showErrorDialog(e.toString());
                }
              },
              child: const Text('Verify now'),
            ),
            TextButton(
              onPressed: () {
                cancelled = true;
                timer?.cancel();
                _isPesapalVerifyDialogOpen = false;
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            )
          ],
        );
      },
    );

    timer?.cancel();
    _isPesapalVerifyDialogOpen = false;
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
    });
    try {
      final url = Uri.parse(
          '${SConstants.sApiBaseUrl}/payments/pesapal/wallet/history?limit=30');
      final accessToken =
          VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };
      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        final parsed = json.decode(res.body) as Map<String, dynamic>;
        final data = parsed['data'] as List? ?? const [];
        setState(() {
          _history = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }
}

class _WalletHistoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _WalletHistoryItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final status = (item['status'] as String?) ?? 'pending';
    final type = (item['type'] as String?) ?? 'TOPUP';
    final isWithdrawal = type == 'WITHDRAWAL';
    
    final confirmationCode = item['confirmationCode'] as String?;
    final paymentMethod = item['paymentMethod'] as String?;
    final createdAt = item['createdAt'];
    DateTime? dt;
    try {
      if (createdAt is String) dt = DateTime.tryParse(createdAt);
      if (createdAt is int) dt = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } catch (_) {}
    final dateStr = dt != null
        ? '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}'
        : '';

    Color chipColor;
    switch (status) {
      case 'success':
        chipColor = Colors.green;
        break;
      case 'failed':
      case 'cancelled':
      case 'reversed':
        chipColor = Colors.redAccent;
        break;
      default:
        chipColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isWithdrawal ? Icons.arrow_upward : Icons.arrow_downward,
              color: chipColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isWithdrawal ? '-' : '+'} KSh ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isWithdrawal ? 'Withdrawal' : 'Top up'} • ${dateStr.isNotEmpty ? dateStr : '—'}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                if (confirmationCode != null &&
                    confirmationCode.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Ref: $confirmationCode',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
                if (paymentMethod != null && paymentMethod.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Via: $paymentMethod',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  color: chipColor, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';
}
