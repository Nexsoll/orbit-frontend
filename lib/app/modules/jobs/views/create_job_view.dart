import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../services/jobs_api_service.dart';

class CreateJobView extends StatefulWidget {
  final Map<String, dynamic>? initialJob;
  const CreateJobView({super.key, this.initialJob});

  @override
  State<CreateJobView> createState() => _CreateJobViewState();
}

class _CreateJobViewState extends State<CreateJobView> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _qualifications = TextEditingController();
  final _location = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  String? _category;
  List<String> _categories = [];
  bool _loading = false;

  late final JobsApiService _api;

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<JobsApiService>();
    final job = widget.initialJob;
    if (job != null) {
      _title.text = (job['title'] ?? job['jobTitle'] ?? '').toString();
      _description.text = (job['description'] ?? '').toString();
      _qualifications.text = (job['qualifications'] ?? '').toString();
      _location.text = (job['location'] ?? '').toString();
      _category = (job['category'] ?? '').toString();

      final sMin = job['salaryMin'];
      final sMax = job['salaryMax'];
      if (sMin != null) _salaryMin.text = sMin.toString();
      if (sMax != null) _salaryMax.text = sMax.toString();
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _api.getCategories();
      if (mounted) setState(() => _categories = list);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final desc = _description.text.trim();
    final qual = _qualifications.text.trim();
    final loc = _location.text.trim();

    if (title.isEmpty || desc.isEmpty || qual.isEmpty || loc.isEmpty || _category == null) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Please fill all fields');
      return;
    }

    int? sMin;
    int? sMax;
    if (_salaryMin.text.trim().isNotEmpty) {
      sMin = int.tryParse(_salaryMin.text.trim());
    }
    if (_salaryMax.text.trim().isNotEmpty) {
      sMax = int.tryParse(_salaryMax.text.trim());
    }

    setState(() => _loading = true);
    VAppAlert.showLoading(context: context);
    try {
      final job = widget.initialJob;
      if (job == null) {
        await _api.createJob(
          title: title,
          description: desc,
          qualifications: qual,
          category: _category!,
          location: loc,
          salaryMin: sMin,
          salaryMax: sMax,
        );
      } else {
        final id = (job['_id'] ?? job['id']).toString();
        await _api.updateJob(
          id: id,
          title: title,
          description: desc,
          qualifications: qual,
          category: _category!,
          location: loc,
          salaryMin: sMin,
          salaryMax: sMax,
          includeSalaryMin: true,
          includeSalaryMax: true,
        );
      }
      if (!mounted) return;
      context.pop();
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: widget.initialJob == null ? 'Job posted' : 'Job updated',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(widget.initialJob == null ? 'Create Job' : 'Edit Job'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading ? null : _submit,
          child: Text(widget.initialJob == null ? 'Post' : 'Save'),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _field(label: 'Title', controller: _title),
              const SizedBox(height: 12),
              _pickerField(
                label: 'Category',
                value: _category,
                items: _categories,
                onPicked: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              _field(label: 'Location', controller: _location),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(label: 'Salary Min (KES)', controller: _salaryMin, keyboard: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(label: 'Salary Max (KES)', controller: _salaryMax, keyboard: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              _multiline(label: 'Job Description', controller: _description),
              const SizedBox(height: 12),
              _multiline(label: 'Qualifications', controller: _qualifications),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({required String label, required TextEditingController controller, TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboard,
        ),
      ],
    );
  }

  Widget _multiline({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          maxLines: 6,
        ),
      ],
    );
  }

  Widget _pickerField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String> onPicked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: items.isEmpty
              ? null
              : () async {
                  if (items.isEmpty) return;
                  String current = value ?? items.first;
                  final picked = await showCupertinoModalPopup<String>(
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
                  if (picked != null) onPicked(picked);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value ?? 'Tap to select'),
                const Icon(CupertinoIcons.chevron_down),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
