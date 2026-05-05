import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/jobs/views/job_details_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class JobShareMessageWidget extends StatelessWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const JobShareMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  Map<String, dynamic> get _jobData {
    final inner = data['data'];
    if (inner is Map) {
      return Map<String, dynamic>.from(inner);
    }
    return data;
  }

  String get _posterId => (_jobData['posterId'] ??
          _jobData['userId'] ??
          _jobData['ownerId'] ??
          _jobData['createdBy']?['id'] ??
          '')
      .toString();

  String get _title =>
      (_jobData['title'] ?? _jobData['jobTitle'] ?? 'Job').toString();

  String get _location => (_jobData['location'] ?? '').toString();

  String get _category => (_jobData['category'] ?? '').toString();

  String get _description => (_jobData['description'] ?? '').toString();

  String get _qualifications => (_jobData['qualifications'] ?? '').toString();

  String get _salaryText {
    final sMin = _jobData['salaryMin'];
    final sMax = _jobData['salaryMax'];
    if (sMin == null && sMax == null) return '';
    final parts = <String>[];
    if (sMin != null) parts.add(sMin.toString());
    if (sMax != null) parts.add(sMax.toString());
    final joined = parts.join(' - ');
    return joined.isEmpty ? '' : 'KES $joined';
  }

  Future<void> _openDetails(BuildContext context) async {
    if (_jobData.isEmpty) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => JobDetailsView(
          job: _jobData,
        ),
      ),
    );
  }

  Future<void> _contactPoster(BuildContext context) async {
    try {
      if (_posterId.isEmpty) {
        VAppAlert.showErrorSnackBar(
          context: context,
          message: 'Unable to find job poster',
        );
        return;
      }
      await VChatController.I.roomApi.openChatWith(peerId: _posterId);
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final loc = _location;
    final cat = _category;
    final salary = _salaryText;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetails(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.briefcase_fill,
                  size: 18,
                  color: Color(0xFFB48648),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (loc.isNotEmpty) _Tag(text: loc),
                if (cat.isNotEmpty) _Tag(text: cat),
                if (salary.isNotEmpty) _Tag(text: salary),
              ],
            ),
            if (_description.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Job Description',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.3),
              ),
            ],
            if (_qualifications.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Qualifications',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _qualifications,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  height: 1.3,
                  color: Colors.grey.shade700,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: const Color(0xFFB48648),
                    minSize: 30,
                    onPressed: () => _contactPoster(context),
                    child: const Text(
                      'Contact Poster',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.black.withOpacity(0.05),
                  minSize: 30,
                  onPressed: () => _openDetails(context),
                  child: const Icon(
                    CupertinoIcons.info,
                    size: 18,
                    color: Color(0xFFB48648),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
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
}
