import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/core/models/post/post_model.dart';
import 'package:super_up/app/modules/post/create_post_screen.dart';
import 'package:super_up_core/super_up_core.dart';

class PostTabState {
  List<PostModel> posts = [];
  int page = 1;
  bool hasMore = true;
}

class PostTabController extends SLoadingController<PostTabState> {
  PostTabController() : super(SLoadingState(PostTabState()));

  final _apiService = GetIt.I.get<PostApiService>();
  bool _didInit = false;
  final int _limit = 20;

  @override
  void onInit() {
    if (_didInit) return;
    _didInit = true;
    loadPosts();
  }

  @override
  void onClose() {
    _didInit = false;
  }

  Future<void> loadPosts() async {
    vSafeApiCall(
      request: () {
        return _apiService.getPosts(page: 1, limit: _limit);
      },
      onSuccess: (response) {
        data.posts.clear();
        data.posts.addAll(response);
        data.page = 1;
        data.hasMore = response.length >= _limit;
        setStateSuccess();
        update();
      },
    );
  }

  Future<void> refresh() async {
    data.page = 1;
    data.hasMore = true;
    await loadPosts();
  }

  Future<void> loadMore() async {
    if (!data.hasMore) return;
    final nextPage = data.page + 1;
    vSafeApiCall(
      request: () {
        return _apiService.getPosts(page: nextPage, limit: _limit);
      },
      onSuccess: (response) {
        data.posts.addAll(response);
        data.page = nextPage;
        data.hasMore = response.length >= _limit;
        setStateSuccess();
        update();
      },
    );
  }

  void createPost(BuildContext context, PostType type) {
    final tab = switch (type) {
      PostType.image => 'image',
      PostType.video => 'video',
      PostType.reel => 'reel',
      PostType.location => 'location',
      PostType.text => 'text',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(initialTab: tab),
      ),
    );
  }
}
