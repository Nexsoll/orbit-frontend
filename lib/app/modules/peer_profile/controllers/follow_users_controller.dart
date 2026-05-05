import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class FollowUsersController extends SLoadingController<List<SBaseUser>> {
  final _apiService = GetIt.I.get<ProfileApiService>();
  final String userId;
  final bool isFollowersTab;

  FollowUsersController({
    required this.userId,
    required this.isFollowersTab,
  }) : super(SLoadingState([]));

  bool isFinishLoadMore = false;
  bool _isLoadMoreActive = false;
  final _filterDto = VBaseFilter(
    limit: 30,
    page: 1,
  );

  @override
  void onClose() {}

  @override
  void onInit() {
    getData();
  }

  Future<void> getData() async {
    _filterDto.page = 1;
    isFinishLoadMore = false;
    await vSafeApiCall<List<SBaseUser>>(
      onLoading: () async {
        setStateLoading();
      },
      onError: (exception, trace) {
        setStateError(exception);
      },
      request: () async {
        if (isFollowersTab) {
          return _apiService.getFollowers(userId, filter: _filterDto);
        }
        return _apiService.getFollowing(userId, filter: _filterDto);
      },
      onSuccess: (response) {
        value.data = response;
        setStateSuccess();
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }

  Future<bool> onLoadMore() async {
    if (_isLoadMoreActive || isFinishLoadMore) {
      return false;
    }

    final res = await vSafeApiCall<List<SBaseUser>>(
      onLoading: () {
        _isLoadMoreActive = true;
      },
      request: () async {
        ++_filterDto.page;
        if (isFollowersTab) {
          return _apiService.getFollowers(userId, filter: _filterDto);
        }
        return _apiService.getFollowing(userId, filter: _filterDto);
      },
      onSuccess: (response) {
        if (response.isEmpty) {
          isFinishLoadMore = true;
        }
        _isLoadMoreActive = false;
        value.data.addAll(response);
        notifyListeners();
      },
      onError: (exception, trace) {
        if (kDebugMode) {
          print(exception);
          print(trace);
        }
        _isLoadMoreActive = false;
      },
    );

    if (res == null || res.isEmpty) {
      return false;
    }
    return true;
  }
}
