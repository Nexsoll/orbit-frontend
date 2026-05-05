import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/core/utils/enums.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import 'post_caption_editor.dart';

class CreateTextPost extends StatefulWidget {
  const CreateTextPost({super.key});

  @override
  State<CreateTextPost> createState() => _CreateTextPostState();
}

class _CreateTextPostState extends State<CreateTextPost> {
  final _postApiService = GetIt.I.get<PostApiService>();
  final _captionController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) return;

    await vSafeApiCall(
      onLoading: () {
        setState(() => _isPosting = true);
        VAppAlert.showLoading(context: context);
      },
      request: () async {
        await _postApiService.createTextPost(caption: caption);
      },
      onSuccess: (_) async {
        context.pop();
        context.pop();
        VAppAlert.showSuccessSnackBar(
          context: context,
          message: 'Post created successfully',
        );
      },
      onError: (exception, _) {
        context.pop();
        setState(() => _isPosting = false);
        VAppAlert.showErrorSnackBar(
          context: context,
          message: exception.toString(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF1A1A1A),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF333333)),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: const Icon(CupertinoIcons.clear, color: Colors.white),
        ),
        middle: const Text(
          'Create Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What\'s on your mind?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PostCaptionEditor(
                      controller: _captionController,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  top: BorderSide(color: Color(0xFF333333)),
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: _captionController.text.trim().isEmpty || _isPosting
                        ? const Color(0xFFB48648).withOpacity(0.5)
                        : const Color(0xFFB48648),
                    borderRadius: BorderRadius.circular(12),
                    onPressed:
                        _captionController.text.trim().isEmpty || _isPosting
                            ? null
                            : _submitPost,
                    child: _isPosting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Post',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
