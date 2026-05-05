// Copyright 2025, Orbit
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../../../core/api_service/community/community_api_service.dart';

class CommunitiesTabController extends SLoadingController<List<Map<String, dynamic>>> {
  final CommunityApiService _api = GetIt.I.get<CommunityApiService>();

  CommunitiesTabController() : super(SLoadingState<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]));

  @override
  void onInit() {
    load();
  }

  @override
  void onClose() {
    // nothing to dispose for now
  }

  Future<void> load() async {
    await vSafeApiCall<List<Map<String, dynamic>>>(
      onLoading: () async {
        setStateLoading();
        update();
      },
      request: () async {
        final list = await _api.myCommunities();
        return list
            .where((e) => e is Map)
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      },
      onSuccess: (res) {
        data
          ..clear()
          ..addAll(res);
        if (data.isEmpty) setStateEmpty(); else setStateSuccess();
        update();
      },
      onError: (e, s) {
        setStateError();
        update();
      },
    );
  }

  void addCommunity(Map<String, dynamic> c) {
    data.insert(0, c);
    setStateSuccess();
    update();
  }
}
