import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/api_service/email_backup/email_backup_api_service.dart';
import 'package:super_up_core/super_up_core.dart';

class EmailBackupPage extends StatefulWidget {
  const EmailBackupPage({super.key});

  @override
  State<EmailBackupPage> createState() => _EmailBackupPageState();
}

class _EmailBackupPageState extends State<EmailBackupPage> {
  final _api = EmailBackupApiService();

  // Controllers
  final _primaryEmailCtrl = TextEditingController();
  final _secondaryEmailCtrl = TextEditingController();
  final _encryptionSecretCtrl = TextEditingController();

  // State
  bool _loading = true;
  bool _saving = false;
  bool _runningBackup = false;
  bool _historyLoading = false;
  bool _hasExistingSettings = false;

  // Settings
  String _frequency = 'weekly';
  bool _includeAttachments = true;
  bool _encrypted = false;
  int _sizeLimitMb = 100;
  bool _chats = true;
  bool _media = true;
  bool _contacts = true;

  // History
  List<Map<String, dynamic>> _history = [];

  // Last run info
  String? _lastRunAt;
  String? _nextRunAt;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
  }

  @override
  void dispose() {
    _primaryEmailCtrl.dispose();
    _secondaryEmailCtrl.dispose();
    _encryptionSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _api.getSettings();
      if (data != null && mounted) {
        setState(() {
          _hasExistingSettings = true;
          _primaryEmailCtrl.text = (data['primaryEmail'] ?? '').toString();
          _secondaryEmailCtrl.text = (data['secondaryEmail'] ?? '').toString();
          _frequency = (data['frequency'] ?? 'weekly').toString();
          _includeAttachments = data['includeAttachments'] == true;
          _encrypted = data['encrypted'] == true;
          _sizeLimitMb = (data['sizeLimitMb'] as num?)?.toInt() ?? 100;
          final cats = (data['categories'] as List?) ?? [];
          _chats = cats.contains('chats');
          _media = cats.contains('media');
          _contacts = cats.contains('contacts');
          _lastRunAt = data['lastRunAt']?.toString();
          _nextRunAt = data['nextRunAt']?.toString();
        });
      }
    } catch (_) {
      // no settings yet – that's fine
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final list = await _api.getHistory(limit: 20);
      if (mounted) setState(() => _history = list);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  List<String> get _selectedCategories {
    final cats = <String>[];
    if (_chats) cats.add('chats');
    if (_media) cats.add('media');
    if (_contacts) cats.add('contacts');
    return cats;
  }

  Future<void> _saveSettings() async {
    final email = _primaryEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Primary email is required');
      return;
    }
    if (_selectedCategories.isEmpty) {
      _showError('Select at least one category to back up');
      return;
    }
    if (_encrypted && _encryptionSecretCtrl.text.trim().isEmpty) {
      _showError('Enter an encryption password or disable encryption');
      return;
    }

    setState(() => _saving = true);
    try {
      await _api.updateSettings(
        primaryEmail: email,
        secondaryEmail: _secondaryEmailCtrl.text.trim().isEmpty
            ? null
            : _secondaryEmailCtrl.text.trim(),
        frequency: _frequency,
        includeAttachments: _includeAttachments,
        encrypted: _encrypted,
        encryptionSecret:
            _encrypted ? _encryptionSecretCtrl.text.trim() : null,
        sizeLimitMb: _sizeLimitMb,
        categories: _selectedCategories,
      );
      if (mounted) {
        _hasExistingSettings = true;
        VAppAlert.showSuccessSnackBar(
          message: 'Backup settings saved',
          context: context,
        );
        // Reload to get updated nextRunAt etc.
        _loadSettings();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runBackupNow() async {
    if (!_hasExistingSettings) {
      _showError('Save your settings first before running a backup');
      return;
    }
    setState(() => _runningBackup = true);
    try {
      final result = await _api.runBackupNow();
      if (mounted) {
        final parts = result['parts'] ?? 1;
        final sizeKb =
            ((result['sizeBytes'] as num?)?.toDouble() ?? 0) / 1024;
        VAppAlert.showSuccessSnackBar(
          message:
              'Backup sent! $parts part(s), ${sizeKb.toStringAsFixed(1)} KB',
          context: context,
        );
        _loadHistory();
        _loadSettings();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _runningBackup = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    VAppAlert.showOkAlertDialog(
      context: context,
      title: 'Error',
      content: message.replaceFirst('Exception: ', ''),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Email Backup'),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoBanner(),
                  const SizedBox(height: 16),
                  _buildEmailSection(),
                  const SizedBox(height: 20),
                  _buildCategoriesSection(),
                  const SizedBox(height: 20),
                  _buildFrequencySection(),
                  const SizedBox(height: 20),
                  _buildOptionsSection(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 12),
                  _buildRunNowButton(),
                  if (_lastRunAt != null || _nextRunAt != null) ...[
                    const SizedBox(height: 16),
                    _buildScheduleInfo(),
                  ],
                  const SizedBox(height: 24),
                  _buildHistorySection(),
                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFB48648).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB48648).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.cloud_upload,
              color: Color(0xFFB48648), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Backup your data to email',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your chats, media & contacts will be sent as an encrypted file to your email on a schedule.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Email addresses',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Backups will be sent to these emails.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        CupertinoTextField(
          controller: _primaryEmailCtrl,
          placeholder: 'Primary email (required)',
          keyboardType: TextInputType.emailAddress,
          clearButtonMode: OverlayVisibilityMode.editing,
          prefix: const Padding(
            padding: EdgeInsets.only(left: 10),
            child:
                Icon(CupertinoIcons.mail, size: 18, color: Color(0xFFB48648)),
          ),
        ),
        const SizedBox(height: 10),
        CupertinoTextField(
          controller: _secondaryEmailCtrl,
          placeholder: 'Secondary email (optional)',
          keyboardType: TextInputType.emailAddress,
          clearButtonMode: OverlayVisibilityMode.editing,
          prefix: const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Icon(CupertinoIcons.mail, size: 18, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What to back up',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _categoryTile(
          icon: CupertinoIcons.chat_bubble_2,
          title: 'Chats',
          subtitle: 'Your sent messages (up to 5,000)',
          value: _chats,
          onChanged: (v) => setState(() => _chats = v),
        ),
        _categoryTile(
          icon: CupertinoIcons.photo,
          title: 'Media',
          subtitle: 'Photo & video attachment metadata',
          value: _media,
          onChanged: (v) => setState(() => _media = v),
        ),
        _categoryTile(
          icon: CupertinoIcons.person_2,
          title: 'Contacts',
          subtitle: 'People you follow',
          value: _contacts,
          onChanged: (v) => setState(() => _contacts = v),
        ),
      ],
    );
  }

  Widget _categoryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHigh
            .withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFFB48648)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: const Color(0xFFB48648),
            onChanged: (v) => onChanged(v),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Backup frequency',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: _frequency,
            onValueChanged: (val) {
              if (val != null) setState(() => _frequency = val);
            },
            children: const {
              'daily': Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Daily'),
              ),
              'weekly': Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Weekly'),
              ),
              'monthly': Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Monthly'),
              ),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Options',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _optionRow(
          icon: CupertinoIcons.paperclip,
          title: 'Include attachments',
          subtitle: 'Include media URLs in backup file',
          trailing: CupertinoSwitch(
            value: _includeAttachments,
            activeColor: const Color(0xFFB48648),
            onChanged: (v) => setState(() => _includeAttachments = v),
          ),
        ),
        const SizedBox(height: 8),
        _optionRow(
          icon: CupertinoIcons.lock_shield,
          title: 'Encrypt backup',
          subtitle: 'Protect with a password',
          trailing: CupertinoSwitch(
            value: _encrypted,
            activeColor: const Color(0xFFB48648),
            onChanged: (v) => setState(() => _encrypted = v),
          ),
        ),
        if (_encrypted) ...[
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: _encryptionSecretCtrl,
            placeholder: 'Encryption password',
            obscureText: true,
            clearButtonMode: OverlayVisibilityMode.editing,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child:
                  Icon(CupertinoIcons.lock, size: 18, color: Color(0xFFB48648)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(CupertinoIcons.doc, size: 18, color: Color(0xFFB48648)),
            const SizedBox(width: 8),
            const Text('Max file size',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showSizePicker(),
              child: Text(
                '$_sizeLimitMb MB',
                style: const TextStyle(
                  color: Color(0xFFB48648),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _optionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHigh
            .withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFFB48648)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  void _showSizePicker() {
    final options = [10, 25, 50, 100, 200, 500];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Max file size per email'),
        actions: options
            .map(
              (mb) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() => _sizeLimitMb = mb);
                  Navigator.pop(ctx);
                },
                isDefaultAction: mb == _sizeLimitMb,
                child: Text('$mb MB'),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: _saving ? null : _saveSettings,
        child: _saving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(_hasExistingSettings ? 'Update Settings' : 'Save Settings'),
      ),
    );
  }

  Widget _buildRunNowButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: CupertinoColors.systemGrey5,
        onPressed: _runningBackup ? null : _runBackupNow,
        child: _runningBackup
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Sending backup…',
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
              )
            : const Text(
                'Backup Now',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildScheduleInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          if (_lastRunAt != null)
            _scheduleRow('Last backup', _formatDate(_lastRunAt)),
          if (_nextRunAt != null) ...[
            if (_lastRunAt != null) const SizedBox(height: 6),
            _scheduleRow('Next backup', _formatDate(_nextRunAt)),
          ],
        ],
      ),
    );
  }

  Widget _scheduleRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Backup History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _historyLoading ? null : _loadHistory,
              child: _historyLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.refresh, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_history.isEmpty && !_historyLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No backups yet',
                  style: TextStyle(color: Colors.black54)),
            ),
          )
        else
          ..._history.map(_buildHistoryItem).toList(),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'failed').toString();
    final isSuccess = status == 'success';
    final sizeBytes = (item['sizeBytes'] as num?)?.toDouble();
    final parts = (item['parts'] as num?)?.toInt() ?? 1;
    final categories = (item['categories'] as List?)?.join(', ') ?? '';
    final failureReason = item['failureReason']?.toString();
    final startedAt = item['startedAt']?.toString() ?? item['createdAt']?.toString();

    String sizeStr = '';
    if (sizeBytes != null && sizeBytes > 0) {
      if (sizeBytes > 1024 * 1024) {
        sizeStr = '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        sizeStr = '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
      }
    }

    final chipColor = isSuccess ? Colors.green : Colors.redAccent;

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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSuccess
                  ? CupertinoIcons.checkmark_circle
                  : CupertinoIcons.xmark_circle,
              color: chipColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(startedAt),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                if (categories.isNotEmpty)
                  Text(
                    categories,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                if (sizeStr.isNotEmpty)
                  Text(
                    '$sizeStr • $parts part(s)',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                if (!isSuccess &&
                    failureReason != null &&
                    failureReason != 'pending')
                  Text(
                    failureReason,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                color: chipColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
