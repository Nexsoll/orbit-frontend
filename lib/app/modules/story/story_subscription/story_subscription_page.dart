// Copyright 2026
// Story subscription plans page

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:super_up_core/super_up_core.dart';
import '../../../core/api_service/story/story_api.dart';
import '../../../core/services/balance_service.dart';
import 'package:url_launcher/url_launcher.dart';

class StorySubscriptionPage extends StatefulWidget {
  const StorySubscriptionPage({super.key});

  @override
  State<StorySubscriptionPage> createState() => _StorySubscriptionPageState();
}

class _StorySubscriptionPageState extends State<StorySubscriptionPage>
    with WidgetsBindingObserver {
  bool _loading = false;
  bool _subscribing = false;
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _activeSub;

  String? _pendingOrderTrackingId;
  String? _pendingRedirectUrl;
  bool _isVerifyDialogOpen = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyPendingSubscription();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final plans = await _fetchPlans();
      final sub = await _fetchActive();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _activeSub = sub;
      });
    } catch (e) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

  String _purchaseErrorMessage(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('insufficient balance')) {
      return 'Low balance. Please top up your account balance and try again.';
    }
    return message;
  }

  Future<void> _showPurchaseMessage({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Map<String, String> _authHeaders() {
    final accessToken =
        VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw Exception('Login required. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Future<List<Map<String, dynamic>>> _fetchPlans() async {
    final url = Uri.parse(
        '${StoryApi.storyReelsServiceBaseUrl}/story-subscriptions/plans');
    final res = await http
        .get(url, headers: _authHeaders())
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractBackendMessage(res.body));
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      throw Exception((parsed['message'] ?? 'Failed to load plans').toString());
    }
    final data = parsed['data'] as List? ?? const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>?> _fetchActive() async {
    final url = Uri.parse(
        '${StoryApi.storyReelsServiceBaseUrl}/story-subscriptions/me');
    final res = await http
        .get(url, headers: _authHeaders())
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractBackendMessage(res.body));
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      return null;
    }
    final data = parsed['data'] as Map<String, dynamic>?;
    if (data == null || data['active'] != true) return null;
    return data['subscription'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> _subscribe(String planKey) async {
    final url = Uri.parse(
        '${StoryApi.storyReelsServiceBaseUrl}/story-subscriptions/subscribe');
    final res = await http
        .post(
          url,
          headers: _authHeaders(),
          body: jsonEncode({'plan': planKey}),
        )
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

  Future<Map<String, dynamic>?> _subscribeWithWallet(String planKey) async {
    final url = Uri.parse(
      '${StoryApi.storyReelsServiceBaseUrl}/story-subscriptions/subscribe/wallet',
    );
    final res = await http
        .post(
          url,
          headers: _authHeaders(),
          body: jsonEncode({'plan': planKey}),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractBackendMessage(res.body));
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      throw Exception(
        (parsed['message'] ?? 'Failed to activate subscription').toString(),
      );
    }
    return parsed['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> _confirm(String orderTrackingId) async {
    final url = Uri.parse(
        '${StoryApi.storyReelsServiceBaseUrl}/story-subscriptions/confirm');
    final res = await http
        .post(
          url,
          headers: _authHeaders(),
          body: jsonEncode({'orderTrackingId': orderTrackingId}),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractBackendMessage(res.body));
    }
    final parsed = json.decode(res.body) as Map<String, dynamic>;
    if ((parsed['code'] as int?) != 2000) {
      throw Exception(
          (parsed['message'] ?? 'Payment not completed').toString());
    }
    return parsed['data'] as Map<String, dynamic>;
  }

  Future<void> _startSubscription(String planKey) async {
    if (_subscribing) return;
    setState(() => _subscribing = true);
    try {
      VAppAlert.showLoading(
        context: context,
        message: 'Initiating PesaPal payment...',
      );
      final tx = await _subscribe(planKey);
      _hideLoadingDialog();
      if (tx == null) return;

      final redirectUrl = (tx['redirectUrl'] ?? '').toString();
      final orderTrackingId = (tx['orderTrackingId'] ?? '').toString();
      if (orderTrackingId.isEmpty) {
        throw Exception('Failed to start PesaPal payment');
      }

      if (redirectUrl.isNotEmpty) {
        final uri = Uri.tryParse(redirectUrl);
        if (uri != null) {
          final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          if (!ok) {
            final ok2 =
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!ok2) {
              throw Exception('Failed to open PesaPal payment page');
            }
          }
        } else {
          throw Exception('PesaPal payment URL is invalid');
        }
      } else {
        throw Exception('PesaPal payment URL is missing');
      }

      _pendingOrderTrackingId = orderTrackingId;
      _pendingRedirectUrl = redirectUrl;
      await _showVerifyDialog(orderTrackingId, redirectUrl: redirectUrl);
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  Future<void> _startWalletSubscription(String planKey) async {
    if (_subscribing) return;
    setState(() => _subscribing = true);
    try {
      final data = await _subscribeWithWallet(planKey);
      if (data == null || data['active'] != true) {
        throw Exception('Failed to activate subscription');
      }

      await BalanceService.instance.init();
      if (!mounted) return;
      setState(
          () => _activeSub = data['subscription'] as Map<String, dynamic>?);
      await _showPurchaseMessage(
        title: 'Purchase Successful',
        message: 'Purchase successful. Your story plan is active.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await _showPurchaseMessage(
        title: 'Purchase Failed',
        message: _purchaseErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  void _hideLoadingDialog() {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _verifyPendingSubscription() async {
    if (!mounted) return;
    if (!_isVerifyDialogOpen) return;
    if (_verifying) return;
    final trackingId = (_pendingOrderTrackingId ?? '').trim();
    if (trackingId.isEmpty) return;

    _verifying = true;
    try {
      final data = await _tryConfirm(trackingId);
      if (data == null) return;
      final active = data['active'] == true;
      if (active) {
        _pendingOrderTrackingId = null;
        _pendingRedirectUrl = null;
        if (_isVerifyDialogOpen) {
          _isVerifyDialogOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        final sub = data['subscription'] as Map<String, dynamic>?;
        if (mounted) {
          setState(() => _activeSub = sub);
          VAppAlert.showSuccessSnackBar(
            context: context,
            message: 'Purchase successful. Your story plan is active.',
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (_) {
      // ignore
    } finally {
      _verifying = false;
    }
  }

  Future<Map<String, dynamic>?> _tryConfirm(String trackingId) async {
    try {
      return await _confirm(trackingId);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('not completed') || msg.contains('pending')) {
        return null;
      }
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
      return null;
    }
  }

  Future<void> _showVerifyDialog(String orderTrackingId,
      {String? redirectUrl}) async {
    bool cancelled = false;
    _isVerifyDialogOpen = true;

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
              _isVerifyDialogOpen = false;
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              VAppAlert.showErrorSnackBar(
                message: 'Verification timed out. Please tap Verify now.',
                context: context,
              );
              return;
            }

            inFlight = true;
            try {
              final data = await _tryConfirm(orderTrackingId);
              if (data != null && data['active'] == true) {
                cancelled = true;
                timer?.cancel();
                _pendingOrderTrackingId = null;
                _pendingRedirectUrl = null;
                _isVerifyDialogOpen = false;
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                final sub = data['subscription'] as Map<String, dynamic>?;
                if (mounted) {
                  setState(() => _activeSub = sub);
                  VAppAlert.showSuccessSnackBar(
                    context: context,
                    message: 'Purchase successful. Your story plan is active.',
                  );
                  Navigator.of(context).pop(true);
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
              Text(
                'Complete the payment in the opened PesaPal page...\n\n'
                'You can pay via M-Pesa, Visa, Mastercard, and more.',
              ),
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
                  final data = await _tryConfirm(orderTrackingId);
                  if (data != null && data['active'] == true) {
                    _pendingOrderTrackingId = null;
                    _pendingRedirectUrl = null;
                    _isVerifyDialogOpen = false;
                    if (context.mounted) Navigator.of(ctx).pop();
                    final sub = data['subscription'] as Map<String, dynamic>?;
                    if (mounted) {
                      setState(() => _activeSub = sub);
                      VAppAlert.showSuccessSnackBar(
                        context: context,
                        message:
                            'Purchase successful. Your story plan is active.',
                      );
                      Navigator.of(context).pop(true);
                    }
                    return;
                  }
                  VAppAlert.showErrorSnackBar(
                    message: 'Payment not completed yet',
                    context: context,
                  );
                } catch (e) {
                  VAppAlert.showErrorSnackBar(
                    message: e.toString(),
                    context: context,
                  );
                }
              },
              child: const Text('Verify now'),
            ),
            TextButton(
              onPressed: () {
                cancelled = true;
                timer?.cancel();
                _isVerifyDialogOpen = false;
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            )
          ],
        );
      },
    );

    timer?.cancel();
    _isVerifyDialogOpen = false;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final d = dt.toLocal();
    return '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Story Plans'),
        trailing: _loading
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _load,
                child: const Icon(CupertinoIcons.refresh),
              ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_activeSub != null) _buildActiveCard(_activeSub!),
                  if (_plans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No plans available. Please check back later.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._plans.map(_buildPlanCard),
                  const SizedBox(height: 12),
                  const Text(
                    'You get 1 free story per type (text, image, video, voice). Upgrade to continue posting.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildActiveCard(Map<String, dynamic> sub) {
    final plan = (sub['plan'] ?? '').toString();
    final expiresAt = _formatDate(sub['expiresAt']?.toString());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.check_mark_circled, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active plan: ${plan.isEmpty ? '-' : plan}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('Expires: $expiresAt'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final title = (plan['title'] ?? plan['key'] ?? 'Plan').toString();
    final amount = (plan['amount'] as num?)?.toDouble() ?? 0;
    final currency = (plan['currency'] ?? 'KES').toString();
    final durationDays = (plan['durationDays'] as num?)?.toInt() ?? 0;
    final key = (plan['key'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('$durationDays days access'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$currency ${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CupertinoButton.filled(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onPressed: _subscribing
                        ? null
                        : () => _startWalletSubscription(key),
                    child: _subscribing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CupertinoActivityIndicator(color: Colors.white),
                          )
                        : const Text('Use Balance'),
                  ),
                  const SizedBox(height: 6),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    onPressed:
                        _subscribing ? null : () => _startSubscription(key),
                    child: const Text('Pay Online'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
