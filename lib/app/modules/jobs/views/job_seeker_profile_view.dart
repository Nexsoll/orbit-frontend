import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../core/services/user_files_service.dart';
import '../services/jobs_api_service.dart';

class JobSeekerProfileView extends StatefulWidget {
  const JobSeekerProfileView({super.key});

  @override
  State<JobSeekerProfileView> createState() => _JobSeekerProfileViewState();
}

class _JobSeekerProfileViewState extends State<JobSeekerProfileView> {
  final _skills = TextEditingController();
  final _years = TextEditingController();
  String? _cvUrl;
  bool _loading = true;
  bool _saving = false;

  late final JobsApiService _api;

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<JobsApiService>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _api.getMySeekerProfile();
      if (p != null) {
        _skills.text = (p['skills'] ?? '').toString();
        final y = p['yearsExperience'];
        if (y != null) _years.text = y.toString();
        _cvUrl = (p['cvUrl'] ?? '') as String?;
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadCv() async {
    try {
      final files = await VAppPick.getFiles();
      if (files == null || files.isEmpty) return;
      VAppAlert.showLoading(context: context);
      final uploaded = await UserFilesService.uploadFiles(files);
      context.pop();
      if (uploaded.isEmpty) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Upload failed');
        return;
      }
      final url = uploaded.first.networkUrl;
      if (url == null || url.isEmpty) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Invalid file URL');
        return;
      }
      setState(() => _cvUrl = url);
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          context.pop();
        }
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      }
    }
  }

  Future<void> _save() async {
    final skills = _skills.text.trim();
    final years = int.tryParse(_years.text.trim());
    setState(() => _saving = true);
    VAppAlert.showLoading(context: context);
    try {
      await _api.updateMySeekerProfile(
        skills: skills.isEmpty ? null : skills,
        yearsExperience: years,
        cvUrl: _cvUrl,
      );
      if (!mounted) return;
      context.pop();
      VAppAlert.showSuccessSnackBar(context: context, message: 'Profile saved');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('Job Seeker Profile'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Skills', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _skills,
                      placeholder: 'e.g. Flutter, Node.js, Accounting',
                    ),
                    const SizedBox(height: 12),
                    const Text('Years of Experience', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _years,
                      keyboardType: TextInputType.number,
                      placeholder: 'e.g. 3',
                    ),
                    const SizedBox(height: 12),
                    const Text('CV / Resume', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _cvUrl == null || _cvUrl!.isEmpty ? 'No file uploaded' : _cvUrl!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          color: const Color(0xFFB48648),
                          onPressed: _pickAndUploadCv,
                          child: const Text('Upload CV'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
