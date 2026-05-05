// Copyright 2025, Orbit
// Verification Request Page

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/core/services/user_files_service.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/modules/home/settings_modules/wallet/views/wallet_page.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class VerificationRequestPage extends StatefulWidget {
  const VerificationRequestPage({super.key});

  @override
  State<VerificationRequestPage> createState() => _VerificationRequestPageState();
}

class _VerificationRequestPageState extends State<VerificationRequestPage> {
  final _profile = ProfileApiService.init();

  VPlatformFile? _idImage;
  VPlatformFile? _selfieImage;
  String? _idImageUrl;
  String? _selfieImageUrl;

  bool _submitting = false;
  Map<String, dynamic>? _latestRequest; // status display

  List<Map<String, dynamic>> _feeOptions(AppConfigModel cfg) {
    final monthly = cfg.verificationFeeMonthly ?? 0;
    final six = cfg.verificationFeeSixMonths ?? 0;
    final yearly = (cfg.verificationFeeYearly ?? cfg.verificationFee) ?? 0;

    final options = <Map<String, dynamic>>[];
    if (monthly > 0) {
      options.add({'plan': 'monthly', 'months': 1, 'fee': monthly, 'label': '1 Month'});
    }
    if (six > 0) {
      options.add({'plan': 'six_months', 'months': 6, 'fee': six, 'label': '6 Months'});
    }
    if (yearly > 0) {
      options.add({'plan': 'yearly', 'months': 12, 'fee': yearly, 'label': '1 Year'});
    }
    return options;
  }

  Future<Map<String, dynamic>?> _selectFeeOption(AppConfigModel cfg) async {
    final options = _feeOptions(cfg);
    if (options.isEmpty) return null;
    if (options.length == 1) return options.first;

    final selected = await showConfirmationDialog<String>(
      context: context,
      title: 'Choose Duration',
      message: 'Select how long you want the verification badge for.',
      actions: options
          .map(
            (o) => AlertDialogAction<String>(
              key: o['plan'] as String,
              label: '${o['label']}  •  KSh ${(o['fee'] as double).toStringAsFixed(2)}',
              isDefaultAction: (o['plan'] as String) == 'yearly',
            ),
          )
          .toList(),
    );

    if (selected == null) return null;
    return options.firstWhere((o) => o['plan'] == selected);
  }

  @override
  void initState() {
    super.initState();
    _loadLatest();
    _refreshConfig();
  }

  Future<void> _refreshConfig() async {
    try {
      final profileApi = ProfileApiService.init();
      final freshConfig = await profileApi.appConfig();
      await VAppPref.setMap(
        SStorageKeys.appConfigModelData.name,
        freshConfig.toMap(),
      );
      if (mounted) setState(() {});
    } catch (_) {
      // ignore - use cached config
    }
  }

  Future<void> _loadLatest() async {
    try {
      final latest = await _profile.getMyLatestVerificationRequest();
      setState(() {
        _latestRequest = latest;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _pickIdImage() async {
    final file = await VAppPick.getImage(isFromCamera: false);
    if (file == null) return;
    setState(() => _idImage = file);
  }

  Future<void> _pickSelfie() async {
    final file = await VAppPick.getImage(isFromCamera: true);
    if (file == null) return;
    setState(() => _selfieImage = file);
  }

  Future<String?> _uploadOne(VPlatformFile file) async {
    final uploaded = await UserFilesService.uploadFiles([file]);
    if (uploaded.isEmpty) return null;
    return uploaded.first.networkUrl;
  }

  Future<void> _submit() async {
    if (_idImage == null || _selfieImage == null) return;
    setState(() => _submitting = true);
    try {
      _idImageUrl ??= await _uploadOne(_idImage!);
      _selfieImageUrl ??= await _uploadOne(_selfieImage!);
      if (_idImageUrl == null || _selfieImageUrl == null) {
        VAppAlert.showErrorSnackBar(
          message: 'Failed to upload images. Please try again.',
          context: context,
        );
        setState(() => _submitting = false);
        return;
      }

      // If a verification fee is configured, initiate M-Pesa payment first
      final appConfig = VAppConfigController.appConfig;
      String? feePlan;
      double selectedFee = 0;
      String selectedLabel = 'Verification fee';
      int selectedMonths = 0;

      final feeOptions = _feeOptions(appConfig);
      final selectedOption = await _selectFeeOption(appConfig);
      if (feeOptions.isNotEmpty && selectedOption == null) {
        setState(() => _submitting = false);
        return;
      }
      if (selectedOption != null) {
        feePlan = selectedOption['plan'] as String;
        selectedFee = selectedOption['fee'] as double;
        selectedLabel = selectedOption['label'] as String;
        selectedMonths = (selectedOption['months'] as int?) ?? 0;
      }

      try {
        // Wallet-based flow: do not pass paymentReference so backend deducts from wallet
        await _profile.createVerificationRequest(
          idImageUrl: _idImageUrl!,
          selfieImageUrl: _selfieImageUrl!,
          feePlan: feePlan,
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final isInsufficient = msg.contains('insufficient') ||
            msg.contains('balance') ||
            msg.contains('400') ||
            msg.contains('bad request');

        if (isInsufficient && selectedFee > 0) {
          setState(() => _submitting = false);
          final r = await VAppAlert.showAskYesNoDialog(
            context: context,
            title: 'Insufficient Balance',
            content:
                'You need KSh ${selectedFee.toStringAsFixed(2)} to submit verification (${selectedLabel}), but your wallet balance is insufficient. Would you like to top up?',
          );
          if (r == 1 && mounted) {
            await Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const WalletPage()),
            );
            if (mounted) {
              await BalanceService.instance.init();
            }
          }
          return;
        }
        rethrow;
      }

      if (selectedFee > 0) {
        await BalanceService.instance.init();
      }

      await _loadLatest();
      setState(() => _submitting = false);

      await showOkAlertDialog(
        context: context,
        title: 'Submitted',
        message: selectedFee > 0
            ? 'Your verification request has been submitted for review. KSh ${selectedFee.toStringAsFixed(2)} has been deducted from your wallet for ${selectedLabel} validity. If admin rejects your request, the amount will be refunded to your wallet. Once approved, your badge will expire after ${selectedMonths > 0 ? '$selectedMonths month(s)' : 'the selected period'}.'
            : 'Your verification request has been submitted. The review may take up to 5 days. Thank you!',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _submitting = false);
      VAppAlert.showErrorSnackBar(message: e.toString(), context: context);
    }
  }

  Widget _buildPickTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    VPlatformFile? picked,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          picked == null ? subtitle : picked.name,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
        ),
        trailing: Icon(Icons.upload, color: Theme.of(context).colorScheme.primary, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = VAppConfigController.appConfig;
    final feeOptions = _feeOptions(appConfig);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Verification')),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attractive Header Section
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFB48648).withValues(alpha: 0.9),
                      const Color(0xFFB48648).withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB48648).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Get Verified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Build trust with a verification badge',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (feeOptions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.money_dollar_circle,
                        color: Color(0xFFB48648),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Verification Plans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                ...feeOptions.map(
                  (o) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFB48648).withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o['label'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${o['months']} month${(o['months'] as int) > 1 ? 's' : ''} validity',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'KSh ${(o['fee'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB48648),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_latestRequest != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _latestRequest!['status'] == 'approved'
                        ? Colors.green.withValues(alpha: 0.1)
                        : _latestRequest!['status'] == 'rejected'
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _latestRequest!['status'] == 'approved'
                          ? Colors.green.withValues(alpha: 0.3)
                          : _latestRequest!['status'] == 'rejected'
                              ? Colors.red.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _latestRequest!['status'] == 'approved'
                            ? CupertinoIcons.checkmark_circle_fill
                            : _latestRequest!['status'] == 'rejected'
                                ? CupertinoIcons.xmark_circle_fill
                                : CupertinoIcons.clock_fill,
                        color: _latestRequest!['status'] == 'approved'
                            ? Colors.green
                            : _latestRequest!['status'] == 'rejected'
                                ? Colors.red
                                : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Latest request: ${_latestRequest!['status'] ?? 'pending'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              _buildPickTile(
                title: 'Upload ID Document',
                subtitle: 'Front of National ID / Passport',
                icon: CupertinoIcons.doc_text_fill,
                onTap: _pickIdImage,
                picked: _idImage,
              ),
              _buildPickTile(
                title: 'Capture Selfie',
                subtitle: 'Take a clear selfie for verification',
                icon: CupertinoIcons.person_crop_circle_fill,
                onTap: _pickSelfie,
                picked: _selfieImage,
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: (_idImage != null && _selfieImage != null && !_submitting) ? _submit : null,
                child: _submitting
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text('Submit for Verification'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
