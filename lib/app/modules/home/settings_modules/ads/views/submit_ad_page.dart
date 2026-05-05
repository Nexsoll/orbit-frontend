import 'dart:io';
import 'dart:typed_data';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up/app/core/services/user_files_service.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:super_up/app/modules/home/settings_modules/wallet/views/wallet_page.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class SubmitAdPage extends StatefulWidget {
  const SubmitAdPage({super.key});

  @override
  State<SubmitAdPage> createState() => _SubmitAdPageState();
}

class _SubmitAdPageState extends State<SubmitAdPage> {
  final _titleCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  VPlatformFile? _bannerFile;
  String? _bannerUrl;
  bool _submitting = false;
  double? _adFee;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFee();
  }

  Widget _buildPickedPreview() {
    try {
      if (_bannerFile?.bytes != null) {
        return Image.memory(
          Uint8List.fromList(_bannerFile!.bytes!),
          fit: BoxFit.cover,
        );
      }
      if (_bannerFile?.fileLocalPath != null) {
        return Image.file(
          File(_bannerFile!.fileLocalPath!),
          fit: BoxFit.cover,
        );
      }
    } catch (_) {}
    return const Center(child: Icon(Icons.image_not_supported_outlined));
  }

  Future<void> _loadFee() async {
    try {
      final cfg = await ProfileApiService.init().appConfig();
      if (!mounted) return;
      setState(() => _adFee = cfg.adSubmissionFee);
    } catch (_) {
      if (!mounted) return;
      setState(() => _adFee = 0);
    }
  }

  Future<void> _pickBanner() async {
    final picked = await VAppPick.getImage(isFromCamera: false);
    if (picked == null) return;
    setState(() => _bannerFile = picked);
  }

  Future<String?> _uploadBanner(VPlatformFile file) async {
    try {
      final uploaded = await UserFilesService.uploadFiles([file]);
      if (uploaded.isEmpty) return null;
      return uploaded.first.networkUrl;
    } catch (e) {
      VAppAlert.showErrorSnackBar(message: e.toString(), context: context);
      return null;
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final link = _linkCtrl.text.trim();

    if (title.isEmpty) {
      VAppAlert.showErrorSnackBar(message: 'Please enter ad title', context: context);
      return;
    }
    if (_bannerFile == null && (_bannerUrl == null || _bannerUrl!.isEmpty)) {
      VAppAlert.showErrorSnackBar(message: 'Please select a banner image', context: context);
      return;
    }

    setState(() => _submitting = true);
    try {
      _bannerUrl ??= _bannerFile != null ? await _uploadBanner(_bannerFile!) : null;
      if (_bannerUrl == null) {
        setState(() => _submitting = false);
        return;
      }

      final fee = (_adFee ?? 0).toDouble();
      if (fee <= 0) {
        // Free submission
        await ProfileApiService.init().createAd(
          title: title,
          imageUrl: _bannerUrl!,
          linkUrl: link.isEmpty ? null : link,
        );

        setState(() => _submitting = false);

        await showOkAlertDialog(
          context: context,
          title: 'Submitted',
          message: 'Your ad was submitted for review. Once approved by admin, it will appear in the top banner slider.',
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      // Paid submission - use wallet
      try {
        await ProfileApiService.init().submitAdWithWallet(
          title: title,
          imageUrl: _bannerUrl!,
          linkUrl: link.isEmpty ? null : link,
        );

        setState(() => _submitting = false);

        // Refresh balance after successful submission
        await BalanceService.instance.init();

        await showOkAlertDialog(
          context: context,
          title: 'Submitted',
          message:
              'Your ad was submitted for review. KSh ${fee.toStringAsFixed(0)} has been deducted from your wallet. If admin rejects the ad, the amount will be refunded to your wallet. Once approved by admin, it will appear in the top banner slider.',
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        final isInsufficient = errorMsg.contains('insufficient') || 
                              errorMsg.contains('balance') || 
                              errorMsg.contains('400') ||
                              errorMsg.contains('bad request');
        
        if (isInsufficient) {
          setState(() => _submitting = false);
          
          // Show insufficient balance dialog with option to top up
          final r = await VAppAlert.showAskYesNoDialog(
            context: context,
            title: 'Insufficient Balance',
            content: 'You need KSh ${fee.toStringAsFixed(0)} to submit this ad, but your wallet balance is insufficient. Would you like to top up?',
          );
          
          if (r == 1 && mounted) {
            // Navigate to wallet page
            await Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const WalletPage()),
            );
            
            // Refresh balance after returning from wallet
            if (mounted) {
              await BalanceService.instance.init();
            }
          }
          return;
        }
        
        // Other error - rethrow to be caught by outer catch
        rethrow;
      }
    } catch (e) {
      setState(() => _submitting = false);
      VAppAlert.showErrorSnackBar(message: e.toString(), context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Submit Ad'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Recommended banner size: 3:1 ratio (e.g., 1200x400).\nYour banner will appear at the top of Settings after admin approval.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              if (_adFee != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_adFee ?? 0) <= 0
                        ? Colors.green.withValues(alpha: 0.12)
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_adFee ?? 0) <= 0
                          ? Colors.green.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        (_adFee ?? 0) <= 0 ? Icons.check_circle : Icons.monetization_on,
                        color: (_adFee ?? 0) <= 0
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ad submission',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (_adFee ?? 0) <= 0
                                  ? 'Currently FREE'
                                  : 'KSh ${(_adFee ?? 0).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Banner preview / picker
              GestureDetector(
                onTap: _pickBanner,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _bannerFile != null
                      ? _buildPickedPreview()
                      : _bannerUrl != null
                          ? Image.network(_bannerUrl!, fit: BoxFit.cover)
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.photo_on_rectangle, size: 28, color: Colors.grey.shade700),
                                  const SizedBox(height: 6),
                                  Text('Tap to select banner', style: TextStyle(color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              CupertinoTextField(
                controller: _titleCtrl,
                placeholder: 'Ad title',
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),

              // Link (optional)
              CupertinoTextField(
                controller: _linkCtrl,
                placeholder: 'Link (optional)',
                padding: const EdgeInsets.all(12),
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text('Submit for Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
