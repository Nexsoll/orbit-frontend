import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:s_translation/generated/l10n.dart';

import '../services/jobs_api_service.dart';
import 'create_job_view.dart';
import '../../report/views/report_page.dart';

class JobsHomeView extends StatefulWidget {
  const JobsHomeView({super.key});

  @override
  State<JobsHomeView> createState() => _JobsHomeViewState();
}

class _JobsHomeViewState extends State<JobsHomeView> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _items = <Map<String, dynamic>>[];
  final _categories = <String>[];
  String? _selectedCategory;
  String? _selectedLocation;
  bool _loading = false;
  Timer? _debounce;

  late final JobsApiService _api;

  static const _brand = Color(0xFFB48648);

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

  Widget _chip({required String text, required BuildContext context}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
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

  Future<void> _applyToJob(Map<String, dynamic> job) async {
    await _showApplySheet(job);
  }

  Future<void> _sendApplication({
    required Map<String, dynamic> job,
    required String cover,
    String? skills,
    int? years,
    VPlatformFile? cvFile,
  }) async {
    final posterId = job['posterId'] ?? job['userId'] ?? job['ownerId'] ?? job['createdBy']?['id'];
    if (posterId == null) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Unable to find job poster');
      return;
    }
    try {
      final room = await VChatController.I.nativeApi.remote.room.getPeerRoom(posterId.toString());

      final title = (job['title'] ?? job['jobTitle'] ?? '').toString();
      final loc = (job['location'] ?? '').toString();
      final cat = (job['category'] ?? '').toString();

      final sb = StringBuffer();
      sb.writeln('Job Application');
      if (title.isNotEmpty) sb.writeln('For: $title');
      if (cat.isNotEmpty) sb.writeln('Category: $cat');
      if (loc.isNotEmpty) sb.writeln('Location: $loc');
      sb.writeln('');
      if (skills != null && skills.trim().isNotEmpty) sb.writeln('Skills: $skills');
      if (years != null) sb.writeln('Experience: $years year(s)');
      sb.writeln('');
      sb.writeln('Cover:');
      sb.writeln(cover);

      // If CV file attached, send it as a file message first
      if (cvFile != null) {
        final fileMsg = VFileMessage.buildMessage(
          roomId: room.id,
          data: VMessageFileData(fileSource: cvFile),
        );
        await VChatController.I.nativeApi.local.message.insertMessage(fileMsg);
        VMessageUploaderQueue.instance
            .addToQueue(await MessageFactory.createUploadMessage(fileMsg));
        sb.writeln('');
        sb.writeln('(CV attached)');
      }

      final textMessage = VTextMessage.buildMessage(
        roomId: room.id,
        content: sb.toString(),
        isEncrypted: false,
        linkAtt: null,
      );

      await VChatController.I.nativeApi.local.message.insertMessage(textMessage);
      VMessageUploaderQueue.instance
          .addToQueue(await MessageFactory.createUploadMessage(textMessage));

      VAppAlert.showSuccessSnackBar(context: context, message: 'Application sent');
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  Future<void> _showApplySheet(Map<String, dynamic> job) async {
    final coverCtrl = TextEditingController();
    final skillsCtrl = TextEditingController();
    final yearsCtrl = TextEditingController();
    VPlatformFile? pickedFile;
    bool sending = false;

    await showCupertinoModalPopup(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.72,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(S.of(context).close),
                        onPressed: sending ? null : () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        'Apply',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: sending
                            ? null
                            : () async {
                                final cover = coverCtrl.text.trim();
                                final years = int.tryParse(yearsCtrl.text.trim());
                                if (cover.isEmpty) {
                                  VAppAlert.showErrorSnackBar(
                                      context: context, message: 'Please add a cover message');
                                  return;
                                }
                                setSheet(() => sending = true);
                                VAppAlert.showLoading(context: context);
                                await _sendApplication(
                                  job: job,
                                  cover: cover,
                                  skills: skillsCtrl.text.trim().isEmpty ? null : skillsCtrl.text.trim(),
                                  years: years,
                                  cvFile: pickedFile,
                                );
                                if (Navigator.of(context).canPop()) context.pop();
                                setSheet(() => sending = false);
                                if (mounted) Navigator.of(context).maybePop();
                              },
                        child: sending
                            ? const CupertinoActivityIndicator()
                            : const Text('Send'),
                      )
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cover Message', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        CupertinoTextField(
                          controller: coverCtrl,
                          maxLines: 5,
                          placeholder: 'Why you are a great fit...',
                        ),
                        const SizedBox(height: 12),
                        const Text('Skills (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        CupertinoTextField(
                          controller: skillsCtrl,
                          placeholder: 'e.g. Flutter, Sales, Accounting',
                        ),
                        const SizedBox(height: 12),
                        const Text('Years of Experience (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        CupertinoTextField(
                          controller: yearsCtrl,
                          keyboardType: TextInputType.number,
                          placeholder: 'e.g. 3',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pickedFile == null ? 'No CV attached' : pickedFile!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              color: _brand,
                              onPressed: sending
                                  ? null
                                  : () async {
                                      final files = await VAppPick.getFiles();
                                      if (files != null && files.isNotEmpty) {
                                        setSheet(() => pickedFile = files.first);
                                      }
                                    },
                              child: const Text(
                                'Attach CV',
                                style: TextStyle(color: CupertinoColors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(S.of(context).jobs),
        trailing: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: () async {
            final res = await context.toPage(const CreateJobView());
            if (res == true) {
              _fetch(reset: true);
            }
          },
          child: Text(
            S.of(context).postAction,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          color: _brand,
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
                      final items = ['All', ..._categories];
                      if (items.isEmpty) return;
                      String current = _selectedCategory ?? 'All';
                      final res = await showCupertinoModalPopup<String>(
                        context: context,
                        builder: (_) => _PickerPopup(items: items, initial: current),
                      );
                      if (!mounted) return;
                      setState(() => _selectedCategory = res == null || res == 'All' ? null : res);
                      _fetch(reset: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  _ChipButton(
                    label: _selectedLocation ?? 'Location',
                    onTap: () async {
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
                      if (!mounted) return;
                      final v = (value ?? '').trim();
                      setState(() => _selectedLocation = v.isEmpty ? null : v);
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
                          final title = (m['title'] ?? m['jobTitle'] ?? 'Untitled').toString();
                          final loc = (m['location'] ?? '').toString();
                          final cat = (m['category'] ?? '').toString();
                          final sMin = m['salaryMin']?.toString();
                          final sMax = m['salaryMax']?.toString();
                          final salary = (sMin != null || sMax != null)
                              ? [if (sMin != null) sMin, if (sMax != null) sMax].join(' - ')
                              : '';
                          final desc = (m['description'] ?? '').toString();
                          final qual = (m['qualifications'] ?? '').toString();
                          final isOwner = _isOwner(m);
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            elevation: 0,
                            color: CupertinoColors.systemGrey6.resolveFrom(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!isOwner) ...[
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          color: _brand,
                                          minSize: 30,
                                          child: const Text('Apply', style: TextStyle(color: CupertinoColors.white)),
                                          onPressed: () => _applyToJob(m),
                                        ),
                                        const SizedBox(width: 6),
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          color: CupertinoColors.destructiveRed,
                                          minSize: 30,
                                          child: const Text('Report', style: TextStyle(color: CupertinoColors.white)),
                                          onPressed: () {
                                            final posterId = _posterId(m);
                                            if (posterId == null) {
                                              VAppAlert.showErrorSnackBar(context: context, message: 'Poster not found');
                                              return;
                                            }
                                            context.toPage(ReportPage(userId: posterId.toString(), jobContext: true));
                                          },
                                        ),
                                      ] else ...[
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          color: _brand,
                                          minSize: 30,
                                          child: const Text('Edit', style: TextStyle(color: CupertinoColors.white)),
                                          onPressed: () => _editJob(m),
                                        ),
                                        const SizedBox(width: 6),
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          color: CupertinoColors.destructiveRed,
                                          minSize: 30,
                                          child: const Text('Delete', style: TextStyle(color: CupertinoColors.white)),
                                          onPressed: () => _deleteJob(m),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (loc.isNotEmpty)
                                        _chip(text: loc, context: context),
                                      if (cat.isNotEmpty)
                                        _chip(text: cat, context: context),
                                      if (salary.isNotEmpty)
                                        _chip(text: 'KES $salary', context: context),
                                    ],
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Job Description:',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      desc,
                                      style: const TextStyle(height: 1.3),
                                    ),
                                  ],
                                  if (qual.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Qualifications:',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(qual),
                                  ],
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          color: Colors.black.withOpacity(0.05),
                                          minSize: 30,
                                          onPressed: () => _shareLink(m),
                                          child: const Icon(
                                            CupertinoIcons.link,
                                            size: 18,
                                            color: _brand,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          color: Colors.black.withOpacity(0.05),
                                          minSize: 30,
                                          onPressed: () => _shareToChat(m),
                                          child: const Icon(
                                            CupertinoIcons.arrowshape_turn_up_right,
                                            size: 18,
                                            color: _brand,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_down, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PickerPopup extends StatelessWidget {
  final List<String> items;
  final String initial;
  const _PickerPopup({required this.items, required this.initial});

  @override
  Widget build(BuildContext context) {
    String current = initial;
    return Container(
      height: 260,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: CupertinoPicker(
              itemExtent: 36,
              scrollController: FixedExtentScrollController(
                initialItem: items.indexOf(initial).clamp(0, items.length - 1),
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
    );
  }
}
