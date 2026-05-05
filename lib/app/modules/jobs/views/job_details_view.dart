import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import '../../report/views/report_page.dart';

class JobDetailsView extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onChatTap;
  const JobDetailsView({super.key, required this.job, this.onChatTap});

  String? _posterId() {
    return (job['posterId'] ?? job['userId'] ?? job['ownerId'] ?? job['createdBy']?['id'])?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final title = (job['title'] ?? job['jobTitle'] ?? 'Job').toString();
    final location = (job['location'] ?? '').toString();
    final category = (job['category'] ?? '').toString();
    final desc = (job['description'] ?? '').toString();
    final qual = (job['qualifications'] ?? '').toString();
    final sMin = job['salaryMin']?.toString();
    final sMax = job['salaryMax']?.toString();
    final salary = (sMin != null || sMax != null) ? [if (sMin != null) sMin, if (sMax != null) sMax].join(' - ') : '';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final id = _posterId();
            if (id == null) {
              VAppAlert.showErrorSnackBar(context: context, message: 'Poster not found');
              return;
            }
            try {
              await VChatController.I.roomApi.openChatWith(peerId: id);
              if (onChatTap != null) onChatTap!();
            } catch (e) {
              VAppAlert.showErrorSnackBar(context: context, message: e.toString());
            }
          },
          child: const Icon(CupertinoIcons.chat_bubble_text_fill, color: Color(0xFFB48648)),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (location.isNotEmpty) _row('Location', location),
              if (category.isNotEmpty) _row('Category', category),
              if (salary.isNotEmpty) _row('Salary (KES)', salary),
              const SizedBox(height: 16),
              const Text('Job Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(desc.isEmpty ? 'No description' : desc),
              const SizedBox(height: 16),
              const Text('Qualifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(qual.isEmpty ? 'Not specified' : qual),
              const SizedBox(height: 28),
              CupertinoButton.filled(
                onPressed: () async {
                  final id = _posterId();
                  if (id == null) return;
                  try {
                    await VChatController.I.roomApi.openChatWith(peerId: id);
                    if (onChatTap != null) onChatTap!();
                  } catch (e) {
                    VAppAlert.showErrorSnackBar(context: context, message: e.toString());
                  }
                },
                child: const Text('Chat with Employer'),
              ),
              const SizedBox(height: 10),
              CupertinoButton(
                color: CupertinoColors.destructiveRed,
                onPressed: () {
                  final id = _posterId();
                  if (id == null) {
                    VAppAlert.showErrorSnackBar(context: context, message: 'Poster not found');
                    return;
                  }
                  context.toPage(ReportPage(userId: id, jobContext: true));
                },
                child: const Text(
                  'Report Employer',
                  style: TextStyle(color: CupertinoColors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(v, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
