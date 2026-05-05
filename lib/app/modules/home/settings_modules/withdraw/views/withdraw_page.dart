import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up_core/super_up_core.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawalStatusResult {
  final bool isSuccess;
  final bool isPending;
  final String? message;

  const _WithdrawalStatusResult({
    required this.isSuccess,
    required this.isPending,
    this.message,
  });
}

class _WithdrawPageState extends State<WithdrawPage> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    BalanceService.instance.init();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = BalanceService.instance.balance;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Withdraw'),
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Withdraw your wallet balance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Withdraw to any mobile money number.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            CupertinoTextField(
              controller: _amountCtrl,
              placeholder: 'Amount (KES)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _phoneCtrl,
              placeholder: 'Phone number (07XXXXXXXX)',
              keyboardType: TextInputType.phone,
              clearButtonMode: OverlayVisibilityMode.editing,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(CupertinoIcons.phone_fill),
              ),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _loading ? null : _onWithdrawPressed,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Withdraw now'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your wallet balance will be debited and the withdrawal will be sent to the number entered above.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onWithdrawPressed() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    final balance = BalanceService.instance.balance;

    if (amount == null || amount <= 0) {
      VAppAlert.showErrorSnackBarWithoutContext(
          message: 'Enter a valid amount');
      return;
    }

    if (amount > balance) {
      VAppAlert.showErrorSnackBarWithoutContext(
          message: 'Insufficient wallet balance');
      return;
    }

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      VAppAlert.showErrorSnackBarWithoutContext(
          message: 'Enter a phone number');
      return;
    }

    setState(() => _loading = true);
    try {
      final txId = await _withdrawToMpesa(
        amount: amount,
        phone: phone,
      );

      if (txId == null) return;

      final status = await _waitForWithdrawalResult(txId);

      await BalanceService.instance.init();
      if (status.isSuccess) {
        VAppAlert.showSuccessSnackBarWithoutContext(
          message: 'Withdrawal completed successfully.',
        );
        _amountCtrl.clear();
        return;
      }

      if (!status.isPending) {
        VAppAlert.showErrorSnackBarWithoutContext(
          message: status.message ?? 'Withdrawal failed',
        );
        return;
      }

      VAppAlert.showSuccessSnackBarWithoutContext(
        message: 'Withdrawal initiated. Your transfer is processing.',
      );
    } catch (e) {
      VAppAlert.showErrorSnackBarWithoutContext(message: 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _withdrawToMpesa({
    required double amount,
    required String phone,
  }) async {
    final url =
        Uri.parse('${SConstants.sApiBaseUrl}/payments/mpesa/wallet/withdraw');
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode({
      'amount': amount,
      'phone': phone,
      'remarks': 'Wallet withdrawal',
    });
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      VAppAlert.showErrorSnackBarWithoutContext(
          message: _readErrorMessage(res.body));
      return null;
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      VAppAlert.showErrorSnackBarWithoutContext(
          message: _pickMessage(parsed));
      return null;
    }
    final data = parsed['data'];
    if (data is Map<String, dynamic>) {
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }
    VAppAlert.showErrorSnackBarWithoutContext(
      message: 'Withdrawal initiated but transaction id was not returned',
    );
    return null;
  }

  Future<_WithdrawalStatusResult> _waitForWithdrawalResult(String txId) async {
    for (var i = 0; i < 6; i++) {
      if (i > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }

      final tx = await _getMpesaTransaction(txId);
      if (tx == null) continue;

      final status = tx['status']?.toString().toLowerCase();
      final resultDesc = tx['resultDesc']?.toString();
      final fallbackMessage = tx['errorMessage']?.toString();

      if (status == 'success') {
        return const _WithdrawalStatusResult(
          isSuccess: true,
          isPending: false,
        );
      }

      if (status == 'failed' || status == 'cancelled' || status == 'timeout') {
        return _WithdrawalStatusResult(
          isSuccess: false,
          isPending: false,
          message: resultDesc != null && resultDesc.isNotEmpty
              ? resultDesc
              : fallbackMessage ?? 'Withdrawal failed',
        );
      }
    }

    return const _WithdrawalStatusResult(
      isSuccess: false,
      isPending: true,
    );
  }

  Future<Map<String, dynamic>?> _getMpesaTransaction(String txId) async {
    final url =
        Uri.parse('${SConstants.sApiBaseUrl}/payments/mpesa/transactions/$txId');
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final res = await http.get(url, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return null;
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      return null;
    }
    final data = parsed['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  String _readErrorMessage(String body) {
    try {
      final parsed = json.decode(body) as Map<String, dynamic>;
      return _pickMessage(parsed);
    } catch (_) {
      return 'Failed to initiate withdrawal';
    }
  }

  String _pickMessage(Map<String, dynamic> parsed) {
    final message = parsed['message'];
    if (message is List && message.isNotEmpty) {
      return message.first.toString();
    }
    return message?.toString() ??
        parsed['msg']?.toString() ??
        parsed['data']?.toString() ??
        'Failed to initiate withdrawal';
  }
}
