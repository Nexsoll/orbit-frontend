import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import '../services/jobs_api_service.dart';
import 'create_job_view.dart';
import 'job_details_view.dart';
import '../../report/views/report_page.dart';

class JobListView extends StatefulWidget {
  const JobListView({super.key});

  @override
  State<JobListView> createState() => _JobListViewState();
}

class _JobListViewState extends State<JobListView> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _items = <Map<String, dynamic>>[];
  final _categories = <String>[];
  String? _selectedCategory;
  String? _selectedLocation;
  bool _loading = false;
  Timer? _debounce;

  late final JobsApiService _api;

  String? _posterId(Map<String, dynamic> job) {
    return (job['posterId'] ?? job['userId'] ?? job['ownerId'] ?? job['createdBy']?['id'])?.toString();
  }

  bool _isOwner(Map<String, dynamic> job) {
    final id = _posterId(job);
    if (id == null) return false;
    return id == AppAuth.myId;
  }

  Future<void> _shareLink(Map<String, dynamic> job) async {
    try {
      final id = (job['_id'] ?? job['id'])?.toString() ?? '';
      if (id.isEmpty) return;

      final title = (job['title'] ?? job['jobTitle'] ?? 'Job Opportunity').toString();
      final loc = (job['location'] ?? '').toString();

      // Use server-side rendered share page for proper WhatsApp/Telegram previews
      final link = 'https://api.orbit.ke/api/v1/public/jobs/share/$id';

      final text = loc.isEmpty
          ? '$title\n$link'
          : '$title\nLocation: $loc\n$link';

      await Share.share(text, subject: title);
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _shareToChat(Map<String, dynamic> job) async {
    try {
      final roomsIds = await VChatController.I.vNavigator.roomNavigator
          .toForwardPage(context, null);
      if (roomsIds == null || roomsIds.isEmpty) return;

      final id = (job['_id'] ?? job['id'])?.toString() ?? '';
      if (id.isEmpty) return;

      final title = (job['title'] ?? job['jobTitle'] ?? 'Job').toString();
      final loc = (job['location'] ?? '').toString();
      final cat = (job['category'] ?? '').toString();
      final desc = (job['description'] ?? '').toString();
      final qual = (job['qualifications'] ?? '').toString();
      final posterId = _posterId(job) ?? '';

      final payload = <String, dynamic>{
        'type': 'job_share',
        'jobId': id,
        '_id': id,
        'title': title,
        'location': loc,
        'category': cat,
        'description': desc,
        'qualifications': qual,
        'salaryMin': job['salaryMin'],
        'salaryMax': job['salaryMax'],
        'posterId': posterId,
      };

      final previewText = 'Shared job: $title';

      VAppAlert.showLoading(context: context);
      try {
        for (final roomId in roomsIds) {
          final message = VCustomMessage.buildMessage(
            roomId: roomId,
            content: previewText,
            data: VCustomMsgData(data: payload),
          );
          await VChatController.I.nativeApi.local.message.insertMessage(message);
          try {
            VMessageUploaderQueue.instance.addToQueue(
              await MessageFactory.createUploadMessage(message),
            );
          } catch (_) {
            // message remains local only
          }
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Shared to chat',
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _editJob(Map<String, dynamic> job) async {
    final res = await context.toPage(CreateJobView(initialJob: job));
    if (res == true) {
      _fetch(reset: true);
    }
  }

  Future<void> _deleteJob(Map<String, dynamic> job) async {
    final id = (job['_id'] ?? job['id'])?.toString();
    if (id == null || id.isEmpty) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Job not found');
      return;
    }

    final confirm = await VAppAlert.showAskYesNoDialog(
      context: context,
      title: 'Delete job',
      content: 'Are you sure you want to delete this job? This action cannot be undone.',
    );
    if (confirm != 1) return;

    VAppAlert.showLoading(context: context);
    try {
      await _api.deleteJob(id);
      if (!mounted) return;
      context.pop();
      setState(() {
        _items.removeWhere((e) => (e['_id'] ?? e['id'])?.toString() == id);
      });
      VAppAlert.showSuccessSnackBar(context: context, message: 'Job deleted');
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        context.pop();
      }
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<JobsApiService>();
    _fetchCategories();
    _fetch(reset: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final list = await _api.getCategories();
      if (mounted) setState(() => _categories..clear()..addAll(list));
    } catch (_) {}
  }

  Future<void> _fetch({required bool reset}) async {
    setState(() => _loading = true);
    try {
      final list = await _api.listJobs(
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        category: _selectedCategory,
        location: _selectedLocation,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(list);
      });
    } catch (e) {
      if (mounted) VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetch(reset: true));
  }

  Future<void> _openChatWithPoster(Map<String, dynamic> job) async {
    try {
      final posterId = job['posterId'] ?? job['userId'] ?? job['ownerId'] ?? job['createdBy']?['id'];
      if (posterId == null) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Unable to find job poster');
        return;
      }
      await VChatController.I.roomApi.openChatWith(peerId: posterId.toString());
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('Jobs'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh),
          onPressed: () => _fetch(reset: true),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                placeholder: 'Search jobs, e.g. "Driver", "Cashier"',
                onChanged: _onSearchChanged,
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _ChipButton(
                    label: _selectedCategory ?? 'All Categories',
                    onTap: () async {
                      final val = await _pickCategory(context);
                      if (!mounted) return;
                      setState(() => _selectedCategory = val);
                      _fetch(reset: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  _ChipButton(
                    label: _selectedLocation ?? 'Location',
                    onTap: () async {
                      final val = await _pickLocation(context);
                      if (!mounted) return;
                      setState(() => _selectedLocation = val);
                      _fetch(reset: true);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const Center(child: CupertinoActivityIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _fetch(reset: true),
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withOpacity(.2)),
                        itemBuilder: (context, index) {
                          final m = _items[index];
                          final isOwner = _isOwner(m);
                          final title = (m['title'] ?? m['jobTitle'] ?? 'Untitled').toString();
                          final loc = (m['location'] ?? '').toString();
                          final cat = (m['category'] ?? '').toString();
                          final sMin = m['salaryMin']?.toString();
                          final sMax = m['salaryMax']?.toString();
                          final salary = (sMin != null || sMax != null)
                              ? [if (sMin != null) sMin, if (sMax != null) sMax].join(' - ')
                              : '';
                          return ListTile(
                            onTap: () => _openChatWithPoster(m),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (loc.isNotEmpty) Text(loc),
                                if (cat.isNotEmpty) Text(cat),
                                if (salary.isNotEmpty) Text('KES $salary'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Icon(
                                    CupertinoIcons.link,
                                    color: Color(0xFFB48648),
                                  ),
                                  onPressed: () => _shareLink(m),
                                ),
                                const SizedBox(width: 6),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Icon(
                                    CupertinoIcons.arrowshape_turn_up_right,
                                    color: Color(0xFFB48648),
                                  ),
                                  onPressed: () => _shareToChat(m),
                                ),
                                const SizedBox(width: 6),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Icon(CupertinoIcons.info, color: Color(0xFFB48648)),
                                  onPressed: () => context.toPage(
                                    JobDetailsView(job: m, onChatTap: () => _openChatWithPoster(m)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isOwner) ...[
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: const Icon(CupertinoIcons.pencil, color: Color(0xFFB48648)),
                                    onPressed: () => _editJob(m),
                                  ),
                                  const SizedBox(width: 6),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: const Icon(CupertinoIcons.delete_solid, color: CupertinoColors.destructiveRed),
                                    onPressed: () => _deleteJob(m),
                                  ),
                                ] else ...[
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: const Icon(CupertinoIcons.flag_fill, color: CupertinoColors.destructiveRed),
                                    onPressed: () {
                                      final posterId = _posterId(m);
                                      if (posterId == null) {
                                        VAppAlert.showErrorSnackBar(context: context, message: 'Poster not found');
                                        return;
                                      }
                                      context.toPage(ReportPage(userId: posterId.toString(), jobContext: true));
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickCategory(BuildContext context) async {
    if (_categories.isEmpty) return null;
    final items = ['All', ..._categories];
    String current = _selectedCategory ?? 'All';
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (_) => Container(
        height: 260,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController: FixedExtentScrollController(
                  initialItem: items.indexOf(current).clamp(0, items.length - 1),
                ),
                onSelectedItemChanged: (i) => current = items[i],
                children: items.map((e) => Center(child: Text(e))).toList(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Select'),
                  onPressed: () => Navigator.pop(context, current),
                ),
              ],
            )
          ],
        ),
      ),
    );
    if (result == null) return null;
    return result == 'All' ? null : result;
  }

  Future<String?> _pickLocation(BuildContext context) async {
    final controller = TextEditingController(text: _selectedLocation ?? '');
    final value = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Filter by location'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: controller,
              placeholder: 'e.g. Nairobi, Mombasa',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Apply'),
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    );
    if (value == null) return null;
    final v = value.trim();
    return v.isEmpty ? null : v;
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_down, size: 16),
          ],
        ),
      ),
    );
  }
}
