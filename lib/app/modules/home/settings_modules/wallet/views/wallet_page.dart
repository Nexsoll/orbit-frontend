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
import 'package:super_up/app/core/api_service/profile/profile_api_service.dart';
import 'package:super_up/app/modules/send_money/views/send_money_user_picker.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:get_it/get_it.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _bankCodeCtrl = TextEditingController();
  bool _loading = false;
  bool _isWithdraw = false;
  String _withdrawProvider = 'MPESA';
  List<Map<String, dynamic>>? _history;
  bool _historyLoading = false;

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
    // Always refresh balance when opening wallet
    BalanceService.instance.init();
    _loadHistory();
    // Pre-fill phone number from profile
    try {
      final myPhone = AppAuth.myProfile.phoneNumber;
      if (myPhone != null && myPhone.isNotEmpty) {
        _phoneCtrl.text = myPhone;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _accountNumberCtrl.dispose();
    _bankCodeCtrl.dispose();
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
                  Row(
                    children: [
                      CupertinoButton(
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
                      const SizedBox(width: 12),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                        onPressed: _loading ? null : _onSendMoneyTap,
                        child: const Text(
                          'Send Money',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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
                      _bankCodeCtrl.clear();
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
            if (!_isWithdraw) ...[
              CupertinoTextField(
                controller: _phoneCtrl,
                placeholder: 'M-Pesa phone number (e.g. 07XXXXXXXX)',
                keyboardType: TextInputType.phone,
                clearButtonMode: OverlayVisibilityMode.editing,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(CupertinoIcons.phone_fill),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isWithdraw) ...[
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _withdrawProvider,
                onValueChanged: (value) {
                  if (_loading || value == null) return;
                  setState(() {
                    _withdrawProvider = value;
                    _bankCodeCtrl.clear();
                  });
                },
                children: const {
                  'MPESA': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('M-Pesa'),
                  ),
                  'AIRTEL_MONEY': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Airtel'),
                  ),
                  'BANK': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Bank'),
                  ),
                },
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _accountNumberCtrl,
                placeholder: _withdrawAccountPlaceholder,
                keyboardType: _withdrawProvider == 'BANK'
                    ? TextInputType.text
                    : TextInputType.phone,
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 12),
              if (_withdrawProvider == 'BANK') ...[
                CupertinoTextField(
                  controller: _bankCodeCtrl,
                  placeholder: 'Bank code',
                  keyboardType: TextInputType.text,
                  clearButtonMode: OverlayVisibilityMode.editing,
                ),
                const SizedBox(height: 12),
              ],
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
              onPressed: _loading
                  ? null
                  : (_isWithdraw ? _onWithdrawPressed : _onTopUpPressed),
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
                'After you press Top up, you will receive an M-Pesa prompt on your phone. '
                'Enter your M-Pesa PIN to complete the payment. '
                'Your wallet balance will update automatically.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              )
            else
              const Text(
                'Withdrawal requests are processed via M-Pesa. Withdrawals '
                'may take some time to reflect in your account. Minimum withdrawal is KES 50.',
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
              ..._history!.map((h) => _WalletHistoryItem(item: h)),
          ],
        ),
      ),
    );
  }

  String get _withdrawAccountPlaceholder {
    if (_withdrawProvider == 'BANK') return 'Bank account number';
    if (_withdrawProvider == 'AIRTEL_MONEY') return 'Airtel Money number';
    return 'M-Pesa phone number';
  }

  Future<void> _onTopUpPressed() async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amountCtrl.text.trim());
    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty) {
      await _showErrorDialog('Enter your M-Pesa phone number');
      return;
    }
    if (amount == null || amount <= 0) {
      await _showErrorDialog('Enter a valid amount');
      return;
    }

    setState(() => _loading = true);
    try {
      VAppAlert.showLoading(
          context: context, message: 'Sending M-Pesa prompt...');
      final tx = await _initiateMpesaStkPush(amount: amount, phone: phone);
      _hideAnyLoadingDialog();
      if (tx == null) return;

      final txId = (tx['id'] ?? '').toString();
      final checkoutRequestId =
          (tx['checkoutRequestId'] ?? '').toString();

      if (txId.isEmpty) {
        await _showErrorDialog('Failed to initiate M-Pesa payment');
        return;
      }

      await _showMpesaStatusDialog(
        txId: txId,
        checkoutRequestId: checkoutRequestId,
      );
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
    final bankCode = _bankCodeCtrl.text.trim();

    if (amount == null || amount < 50) {
      await _showErrorDialog('Minimum withdrawal amount is KES 50');
      return;
    }
    final balance = BalanceService.instance.balance;
    if (amount > balance) {
      await _showErrorDialog('Not sufficient balance');
      return;
    }
    if (account.isEmpty) {
      await _showErrorDialog(
          'Enter ${_withdrawProvider == 'BANK' ? 'your account number' : 'your phone number'}');
      return;
    }
    if (_withdrawProvider == 'BANK' && bankCode.isEmpty) {
      await _showErrorDialog('Enter your bank code');
      return;
    }

    setState(() => _loading = true);
    try {
      VAppAlert.showLoading(
          context: context, message: 'Initiating withdrawal...');
      final data = await _requestWithdrawal(
        amount: amount,
        account: account,
        bankCode: bankCode.isEmpty ? null : bankCode,
      );
      _hideAnyLoadingDialog();

      if (mounted) {
        VAppAlert.showSuccessSnackBar(
            message: _withdrawProvider == 'MPESA'
                ? 'M-Pesa withdrawal initiated'
                : 'Withdrawal request submitted',
            context: context);
      }

      // Update balance and history after withdrawal
      _updateBalanceFromWithdrawalResponse(data);
      await _loadHistory();

      // Clear fields
      _amountCtrl.clear();
      _accountNumberCtrl.clear();
      _bankCodeCtrl.clear();
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

  Future<Map<String, dynamic>> _requestWithdrawal({
    required double amount,
    required String account,
    String? bankCode,
  }) async {
    final isMpesa = _withdrawProvider == 'MPESA';
    final url = Uri.parse(
      isMpesa
          ? '${SConstants.sApiBaseUrl}/payments/mpesa/wallet/withdraw'
          : '${SConstants.sApiBaseUrl}/payments/pesapal/withdraw',
    );
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw Exception('Login required. Please login again.');
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode(
      isMpesa
          ? {
              'amount': amount,
              'phone': account,
              'remarks': 'Wallet withdrawal',
            }
          : {
              'amount': amount,
              'currency': 'KES',
              'accountNumber': account,
              'provider': _withdrawProvider,
              if (bankCode != null) 'bankCode': bankCode,
              'description': 'Wallet withdrawal',
            },
    );
    final res = await http
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractBackendMessage(res.body));
    }

    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000 && (parsed['status'] as int?) != 200) {
      if (!parsed.containsKey('data')) {
        throw Exception(
            (parsed['message'] ?? 'Failed to request withdrawal').toString());
      }
    }
    final data = parsed['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  void _updateBalanceFromWithdrawalResponse(Map<String, dynamic> data) {
    final newBalance = data['newBalance'];
    if (newBalance is num) {
      BalanceService.instance.updateBalanceFromResponse(newBalance.toDouble());
      return;
    }
    BalanceService.instance.init();
  }

  /// Calls backend POST /api/v1/payments/mpesa/stk/initiate
  Future<Map<String, dynamic>?> _initiateMpesaStkPush({
    required double amount,
    required String phone,
  }) async {
    final url =
        Uri.parse('${SConstants.sApiBaseUrl}/payments/mpesa/stk/initiate');
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
      'phone': phone,
      'accountReference': 'WalletTopUp',
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
          (parsed['message'] ?? 'Failed to initiate M-Pesa payment')
              .toString());
    }

    return parsed['data'] as Map<String, dynamic>;
  }

  /// Calls backend GET /api/v1/payments/mpesa/transactions/:id
  Future<Map<String, dynamic>?> _getMpesaTransaction(String txId) async {
    try {
      final url = Uri.parse(
          '${SConstants.sApiBaseUrl}/payments/mpesa/transactions/$txId');
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

  Future<void> _showMpesaStatusDialog({
    required String txId,
    required String checkoutRequestId,
  }) async {
    bool cancelled = false;
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

            if (DateTime.now().difference(startedAt).inSeconds > 120) {
              cancelled = true;
              timer?.cancel();
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              VAppAlert.showErrorSnackBar(
                  message:
                      'Timed out waiting for M-Pesa. Check your balance later.',
                  context: context);
              return;
            }

            inFlight = true;
            try {
              final data = await _getMpesaTransaction(txId);
              final status =
                  (data?['status'] ?? '').toString().trim().toLowerCase();
              if (status == 'success') {
                cancelled = true;
                timer?.cancel();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                await BalanceService.instance.init();
                await _loadHistory();
                if (mounted) {
                  VAppAlert.showSuccessSnackBar(
                      message: 'Top up successful!', context: context);
                }
              } else if (status == 'failed' ||
                  status == 'cancelled' ||
                  status == 'timeout') {
                cancelled = true;
                timer?.cancel();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                final desc = (data?['resultDesc'] ?? '').toString();
                await _showErrorDialog(
                    desc.isNotEmpty ? desc : 'M-Pesa payment $status');
              }
            } finally {
              inFlight = false;
            }
          });
        });

        return AlertDialog(
          title: const Text('M-Pesa Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text(
                'An M-Pesa prompt has been sent to your phone.\n\n'
                'Please enter your M-Pesa PIN to complete the payment.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (cancelled) return;
                try {
                  final data = await _getMpesaTransaction(txId);
                  final status =
                      (data?['status'] ?? '').toString().trim().toLowerCase();
                  if (status == 'success') {
                    cancelled = true;
                    timer?.cancel();
                    if (context.mounted) Navigator.of(ctx).pop();
                    await BalanceService.instance.init();
                    await _loadHistory();
                    if (mounted) {
                      VAppAlert.showSuccessSnackBar(
                          message: 'Top up successful!', context: context);
                    }
                    return;
                  } else if (status == 'failed' ||
                      status == 'cancelled' ||
                      status == 'timeout') {
                    cancelled = true;
                    timer?.cancel();
                    if (context.mounted) Navigator.of(ctx).pop();
                    final desc = (data?['resultDesc'] ?? '').toString();
                    await _showErrorDialog(
                        desc.isNotEmpty ? desc : 'M-Pesa payment $status');
                    return;
                  }
                  VAppAlert.showErrorSnackBar(
                      message: 'Payment not completed yet. Please wait.',
                      context: context);
                } catch (e) {
                  await _showErrorDialog(e.toString());
                }
              },
              child: const Text('Check now'),
            ),
            TextButton(
              onPressed: () {
                cancelled = true;
                timer?.cancel();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    timer?.cancel();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
    });
    try {
      final url = Uri.parse(
          '${SConstants.sApiBaseUrl}/payments/mpesa/wallet/history?limit=30');
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

  Future<void> _onSendMoneyTap() async {
    final selectedUser = await showCupertinoModalBottomSheet<SSearchUser?>(
      expand: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SendMoneyUserPicker(),
    );
    if (selectedUser == null) return;

    final receiverId = selectedUser.baseUser.id;
    final receiverName = selectedUser.baseUser.fullName;

    // Amount dialog
    final amtCtrl = TextEditingController();
    String? res;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Send to $receiverName'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: amtCtrl,
            placeholder: 'Amount (KES)',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              res = 'ok';
              Navigator.pop(ctx);
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (res != 'ok') return;
    final amount = num.tryParse(amtCtrl.text.trim());
    if (amount == null || amount <= 0) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Enter a valid amount',
      );
      return;
    }

    // Password confirmation
    final verified = await _verifyPassword();
    if (!verified) return;

    VAppAlert.showLoading(context: context);
    try {
      await GetIt.I.get<ProfileApiService>().sendMoney(
        receiverId: receiverId,
        amount: amount,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await BalanceService.instance.init();
      await _loadHistory();

      // Success dialog
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Success'),
          content: Text('KES ${amount.toStringAsFixed(0)} sent to $receiverName'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final err = e.toString().toLowerCase();
      final message = err.contains('insufficient') || err.contains('balance')
          ? 'Insufficient balance. Please top up your wallet.'
          : e.toString();
      VAppAlert.showErrorSnackBar(context: context, message: message);
    }
  }

  Future<bool> _verifyPassword() async {
    final passwordCtrl = TextEditingController();
    bool confirmed = false;
    bool obscure = true;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Confirm with password'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: passwordCtrl,
              placeholder: 'Password',
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              suffix: CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                minSize: 0,
                onPressed: () => setDialogState(() => obscure = !obscure),
                child: Icon(
                  obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                confirmed = true;
                Navigator.pop(ctx);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    if (!confirmed) return false;
    final password = passwordCtrl.text.trim();
    if (password.isEmpty) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Password is required',
      );
      return false;
    }
    VAppAlert.showLoading(context: context);
    try {
      await GetIt.I.get<ProfileApiService>().passwordCheck(password);
      if (!mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      return true;
    } catch (e) {
      if (!mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Incorrect password',
      );
      return false;
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

    final confirmationCode =
        (item['mpesaReceiptNumber'] ?? item['confirmationCode']) as String?;
    final paymentMethod = (item['paymentMethod'] as String?) ?? 'M-Pesa';
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
              color: chipColor.withValues(alpha: 0.1),
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
              color: chipColor.withValues(alpha: 0.12),
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
