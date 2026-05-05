import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/api_service/story/story_api_service.dart';
import 'package:super_up/app/core/models/story/story_viewer_model.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';

class StoryViewersScreen extends StatefulWidget {
  final String storyId;
  final String storyTitle;

  const StoryViewersScreen({
    super.key,
    required this.storyId,
    required this.storyTitle,
  });

  @override
  State<StoryViewersScreen> createState() => _StoryViewersScreenState();
}

class _StoryViewersScreenState extends State<StoryViewersScreen> {
  final StoryApiService _api = StoryApiService.init();
  List<StoryViewerModel> _viewers = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadViewers();
  }

  Future<void> _loadViewers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    await vSafeApiCall<StoryViewersResponse>(
      request: () async {
        return await _api.getStoryViewers(widget.storyId);
      },
      onSuccess: (response) {
        setState(() {
          _viewers = response.viewers;
          _isLoading = false;
        });
      },
      onError: (exception, trace) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = exception.toString();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.storyTitle,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            if (!_isLoading && !_hasError)
              Text(
                S.of(context).viewsCount(_viewers.length),
                style: context.cupertinoTextTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(
          radius: 20,
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).failedToLoadViewers,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              onPressed: _loadViewers,
              child: Text(S.of(context).retry),
            ),
          ],
        ),
      );
    }

    if (_viewers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.visibility_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).noViewsYet,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context).whenPeopleViewYourStory,
              style: context.cupertinoTextTheme.textStyle.copyWith(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadViewers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _viewers.length,
        itemBuilder: (context, index) {
          final viewer = _viewers[index];
          return _buildViewerItem(viewer);
        },
      ),
    );
  }

  Widget _buildViewerItem(StoryViewerModel viewer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: VCircleAvatar(
          vFileSource: VPlatformFile.fromUrl(
            networkUrl: viewer.viewerInfo.userImage,
          ),
          radius: 24,
        ),
        title: Text(
          viewer.viewerInfo.fullName,
          style: context.cupertinoTextTheme.textStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          format(
            viewer.viewedAt,
            locale: Localizations.localeOf(context).languageCode,
          ),
          style: context.cupertinoTextTheme.textStyle.copyWith(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        onTap: () {
          context.toPage(
            PeerProfileView(peerId: viewer.viewerInfo.id),
          );
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: Colors.grey[50],
      ),
    );
  }
}
