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

class _WithdrawPageState extends State<WithdrawPage> {
  final _amountCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _bankCodeCtrl = TextEditingController();
  String _provider = 'MPESA';
  bool _loading = false;
  bool _historyLoading = false;
  List<Map<String, dynamic>> _withdrawHistory = [];
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    BalanceService.instance.init();
    _loadWithdrawHistory();
    try {
      final myPhone = AppAuth.myProfile.phoneNumber;
      if (myPhone != null && myPhone.isNotEmpty) {
        _accountNumberCtrl.text = myPhone;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountNumberCtrl.dispose();
    _bankCodeCtrl.dispose();
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
              'Submit a withdrawal to mobile money or a bank account.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _provider,
              onValueChanged: (value) {
                if (_loading || value == null) return;
                setState(() {
                  _provider = value;
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
              controller: _amountCtrl,
              placeholder: 'Amount (KES)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _accountNumberCtrl,
              placeholder: _accountPlaceholder,
              keyboardType: _provider == 'BANK'
                  ? TextInputType.text
                  : TextInputType.phone,
              clearButtonMode: OverlayVisibilityMode.editing,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(CupertinoIcons.creditcard_fill),
              ),
            ),
            if (_provider == 'BANK') ...[
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _bankCodeCtrl,
                placeholder: 'Bank code',
                keyboardType: TextInputType.text,
                clearButtonMode: OverlayVisibilityMode.editing,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(CupertinoIcons.building_2_fill),
                ),
              ),
            ],
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
              'Minimum withdrawal is KES 50. M-Pesa withdrawals are sent immediately when backend B2C accepts the request.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              _WithdrawStatusBanner(
                message: _statusMessage!,
                isError: _statusIsError,
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Withdraw history',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: _historyLoading ? null : _loadWithdrawHistory,
                  icon: _historyLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_historyLoading && _withdrawHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_withdrawHistory.isEmpty)
              const Text(
                'No withdrawals yet',
                style: TextStyle(color: Colors.black54),
              )
            else
              ..._withdrawHistory.map((item) => _WithdrawHistoryItem(item)),
          ],
        ),
      ),
    );
  }

  String get _accountPlaceholder {
    if (_provider == 'BANK') return 'Bank account number';
    if (_provider == 'AIRTEL_MONEY') return 'Airtel Money number';
    return 'M-Pesa phone number';
  }

  Future<void> _onWithdrawPressed() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    final balance = BalanceService.instance.balance;

    if (amount == null || amount < 50) {
      _showFeedback('Minimum withdrawal amount is KES 50', isError: true);
      return;
    }

    if (amount > balance) {
      _showFeedback('Insufficient wallet balance', isError: true);
      return;
    }

    final accountNumber = _accountNumberCtrl.text.trim();
    if (accountNumber.isEmpty) {
      _showFeedback(
        'Enter ${_provider == 'BANK' ? 'an account number' : 'a phone number'}',
        isError: true,
      );
      return;
    }

    final bankCode = _bankCodeCtrl.text.trim();
    if (_provider == 'BANK' && bankCode.isEmpty) {
      _showFeedback('Enter a bank code', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await _requestWithdrawal(
        amount: amount,
        accountNumber: accountNumber,
        bankCode: bankCode.isEmpty ? null : bankCode,
      );

      if (data == null) return;

      await _updateBalanceFromWithdrawalResponse(data);
      final mpesaTx =
          _provider == 'MPESA' ? await _waitForMpesaFinalStatus(data) : null;
      await _loadWithdrawHistory();
      _showFeedback(
        _provider == 'MPESA'
            ? _mpesaFeedbackMessage(mpesaTx)
            : 'Withdrawal request submitted. Check history for status.',
        isError: _isFinalMpesaError(mpesaTx),
      );
      _amountCtrl.clear();
      _bankCodeCtrl.clear();
    } catch (e) {
      _showFeedback('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _requestWithdrawal({
    required double amount,
    required String accountNumber,
    String? bankCode,
  }) async {
    final isMpesa = _provider == 'MPESA';
    final url = Uri.parse(
      isMpesa
          ? '${SConstants.sApiBaseUrl}/payments/mpesa/wallet/withdraw'
          : '${SConstants.sApiBaseUrl}/payments/pesapal/withdraw',
    );
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (accessToken == null || accessToken.trim().isEmpty) {
      _showFeedback('Login required. Please login again.', isError: true);
      return null;
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode(
      isMpesa
          ? {
              'amount': amount,
              'phone': accountNumber,
              'remarks': 'Wallet withdrawal',
            }
          : {
              'amount': amount,
              'currency': 'KES',
              'accountNumber': accountNumber,
              'provider': _provider,
              if (bankCode != null) 'bankCode': bankCode,
              'description': 'Wallet withdrawal',
            },
    );
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _showFeedback(_readErrorMessage(res.body), isError: true);
      return null;
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      _showFeedback(_pickMessage(parsed), isError: true);
      return null;
    }
    final data = parsed['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<void> _updateBalanceFromWithdrawalResponse(
      Map<String, dynamic> data) async {
    final newBalance = data['newBalance'];
    if (newBalance is num) {
      BalanceService.instance.updateBalanceFromResponse(newBalance.toDouble());
      return;
    }
    await BalanceService.instance.init();
  }

  Future<void> _loadWithdrawHistory() async {
    if (!mounted) return;
    setState(() => _historyLoading = true);
    try {
      final results = await Future.wait([
        _getWithdrawHistory('/payments/mpesa/wallet/withdraw/history?limit=30'),
        _getWithdrawHistory(
            '/payments/pesapal/wallet/withdraw/history?limit=30'),
      ]);
      final items = <Map<String, dynamic>>[
        ...results[0],
        ...results[1],
      ];
      items.sort((a, b) {
        final ad = _historyDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = _historyDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      if (mounted) {
        setState(() => _withdrawHistory = items.take(30).toList());
      }
    } catch (e) {
      _showFeedback('Failed to load withdraw history: $e', isError: true);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _waitForMpesaFinalStatus(
      Map<String, dynamic> data) async {
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) return null;

    for (var i = 0; i < 5; i++) {
      if (i > 0) {
        await Future.delayed(const Duration(seconds: 3));
      }
      final tx = await _getMpesaTransaction(id);
      final status = tx?['status']?.toString().toLowerCase();
      if (status == 'success' ||
          status == 'failed' ||
          status == 'cancelled' ||
          status == 'timeout') {
        return tx;
      }
    }
    return _getMpesaTransaction(id);
  }

  Future<Map<String, dynamic>?> _getMpesaTransaction(String id) async {
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (accessToken == null || accessToken.trim().isEmpty) return null;
    final res = await http.get(
      Uri.parse('${SConstants.sApiBaseUrl}/payments/mpesa/transactions/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) return null;
    final tx = parsed['data'];
    if (tx is Map<String, dynamic>) return tx;
    return null;
  }

  String _mpesaFeedbackMessage(Map<String, dynamic>? tx) {
    final status = tx?['status']?.toString().toLowerCase();
    final detail = (tx?['resultDesc'] ?? tx?['errorMessage'])?.toString();
    if (status == 'success') {
      return 'M-Pesa withdrawal sent successfully.';
    }
    if (status == 'failed' || status == 'cancelled' || status == 'timeout') {
      return detail == null || detail.isEmpty
          ? 'M-Pesa withdrawal $status.'
          : detail;
    }
    return 'M-Pesa withdrawal is processing. Final success/error depends on Safaricom callback.';
  }

  bool _isFinalMpesaError(Map<String, dynamic>? tx) {
    final status = tx?['status']?.toString().toLowerCase();
    return status == 'failed' || status == 'cancelled' || status == 'timeout';
  }

  Future<List<Map<String, dynamic>>> _getWithdrawHistory(String path) async {
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (accessToken == null || accessToken.trim().isEmpty) return [];
    final res = await http.get(
      Uri.parse('${SConstants.sApiBaseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _readErrorMessage(res.body);
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      throw _pickMessage(parsed);
    }
    final data = parsed['data'];
    if (data is List) {
      return data.whereType<Map>().map((e) {
        return e.map((key, value) => MapEntry(key.toString(), value));
      }).toList();
    }
    return [];
  }

  void _showFeedback(String message, {bool isError = false}) {
    final text = message.trim().isEmpty ? 'Request failed' : message.trim();
    if (mounted) {
      setState(() {
        _statusMessage = text;
        _statusIsError = isError;
      });
    }
    if (isError) {
      VAppAlert.showErrorSnackBarWithoutContext(message: text);
    } else {
      VAppAlert.showSuccessSnackBarWithoutContext(message: text);
    }
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

  DateTime? _historyDate(Map<String, dynamic> item) {
    final raw =
        item['updatedAt'] ?? item['createdAt'] ?? item['walletDebitedAt'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }
}

class _WithdrawStatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _WithdrawStatusBanner({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? CupertinoColors.systemRed : CupertinoColors.activeGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color.resolveFrom(context),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _WithdrawHistoryItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const _WithdrawHistoryItem(this.item);

  @override
  Widget build(BuildContext context) {
    final amount = (item['amount'] as num?)?.toDouble() ??
        double.tryParse(item['amount']?.toString() ?? '') ??
        0.0;
    final status = (item['status'] ?? 'pending').toString();
    final provider = (item['provider'] ?? 'MPESA').toString();
    final displayStatus =
        provider == 'MPESA' && status.toLowerCase() == 'pending'
            ? 'processing'
            : status;
    final destination =
        (item['phone'] ?? item['accountNumber'] ?? '').toString();
    final date = _formatDate(_date(item));
    final statusColor = _statusColor(displayStatus);
    final detail = (item['resultDesc'] ??
            item['responseDescription'] ??
            item['errorMessage'])
        ?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              CupertinoIcons.arrow_up_right,
              color: statusColor.resolveFrom(context),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '- KSh ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    provider.replaceAll('_', ' '),
                    if (destination.isNotEmpty) destination,
                    if (date.isNotEmpty) date,
                  ].join(' • '),
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 12,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              displayStatus.toUpperCase(),
              style: TextStyle(
                color: statusColor.resolveFrom(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static DateTime? _date(Map<String, dynamic> item) {
    final raw =
        item['updatedAt'] ?? item['createdAt'] ?? item['walletDebitedAt'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  static CupertinoDynamicColor _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'approved':
        return CupertinoColors.activeGreen;
      case 'processing':
        return CupertinoColors.systemOrange;
      case 'failed':
      case 'cancelled':
      case 'timeout':
      case 'rejected':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemOrange;
    }
  }
}
