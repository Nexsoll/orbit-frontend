// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';

import '../../../../../core/api_service/profile/profile_api_service.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../peer_profile/views/peer_profile_view.dart';

class UsersTabController extends SLoadingController<List<SSearchUser>> {
  UsersTabController(this.profileApiService) : super(SLoadingState([]));

  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();

  bool isFinishLoadMore = false;
  bool isSearchOpen = false;
  bool _isLoadMoreActive = false;
  final ProfileApiService profileApiService;
  UserFilterDto _filterDto = UserFilterDto.init();
  String? selectedGender;
  String? selectedProfession;
  bool isNearbyFilterActive = false;

  @override
  void onClose() {
    searchController.dispose();
    searchFocusNode.dispose();
    _debounce?.cancel();
  }

  @override
  void onInit() {
    getData();
  }

  Future<void> getUsersDataFromApi() async {
    try {
      // Set loading state so UI shows loader only while fetching
      setStateLoading();
      update();
      log('Getting users data with filter: isNearbyFilterActive=$isNearbyFilterActive');
      
      _filterDto = UserFilterDto.init();
      _filterDto.gender = selectedGender;
      _filterDto.profession = selectedProfession;
      
      if (isNearbyFilterActive) {
        log('Fetching current location for nearby filter...');
        final position = await LocationService.instance.getCurrentLocation();
        
        if (position != null) {
          log('Updating user location on server...');
          try {
            await profileApiService.updateLocation(
              latitude: position.latitude,
              longitude: position.longitude,
            );
            log('Successfully updated user location on server');
            
            _filterDto.latitude = position.latitude;
            _filterDto.longitude = position.longitude;
            _filterDto.maxDistance = 50.0; // 50km radius
            _filterDto.nearbyOnly = true;
          } catch (e) {
            log('Error updating location: $e');
            // Continue with the request even if location update fails
          }
        } else {
          log('Could not get current location');
        }
      }
      
      log('Fetching users with filter: ${_filterDto.toMap()}');
      final users = await profileApiService.appUsers(_filterDto);
      // Shuffle users so the list order changes each time the screen opens
      users.shuffle(math.Random());
      
      data.clear();
      data.addAll(users);
      log('Successfully fetched ${users.length} users');
      
      await VAppPref.setMap("api/users", {
        "data": users.map((e) => e.toMap()).toList(),
      });
      
      // Transition to success state so UI can render the list
      setStateSuccess();
      update();
    } catch (e, stack) {
      final errorMessage = e.toString();
      log('Error in getUsersDataFromApi: $errorMessage', error: e, stackTrace: stack);
      setStateError(errorMessage);
      rethrow;
    }
  }

  void onItemPress(SSearchUser item, BuildContext context) {
    context.toPage(PeerProfileView(
      peerId: item.baseUser.id,
    ));
  }

  Future<bool> onLoadMore() async {
    if (_isLoadMoreActive) {
      return false;
    }
    final res = await vSafeApiCall<List<SSearchUser>>(
      onLoading: () {
        _isLoadMoreActive = true;
      },
      request: () async {
        _filterDto.page = _filterDto.page + 1;
        final users = await profileApiService.appUsers(_filterDto);
        return users;
      },
      onSuccess: (response) {
        if (response.isEmpty) {
          isFinishLoadMore = true;
        }
        notifyListeners();
        _isLoadMoreActive = false;
        data.addAll(response);
        setStateSuccess();
      },
      onError: (exception, trace) {
        if (kDebugMode) {
          print(exception);
        }
        if (kDebugMode) {
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

  Timer? _debounce;

  void closeSearch() {
    isSearchOpen = false;
    searchController.clear();
    isFinishLoadMore = false;
    _filterDto.page = 1;
    notifyListeners();
    getData();
  }

  void updateGenderFilter(String? gender) {
    selectedGender = gender;
    print('Setting gender filter to: $gender');
    getUsersDataFromApi();
    notifyListeners();
  }

  void clearGenderFilter() {
    selectedGender = null;
    _filterDto.gender = null;
    _filterDto.page = 1;
    isFinishLoadMore = false;
    notifyListeners();
    getUsersDataFromApi();
  }

  void updateProfessionFilter(String? profession) {
    selectedProfession = profession;
    print('Setting profession filter to: $profession');
    getUsersDataFromApi();
    notifyListeners();
  }

  void clearProfessionFilter() {
    selectedProfession = null;
    _filterDto.profession = null;
    _filterDto.page = 1;
    isFinishLoadMore = false;
    notifyListeners();
    getUsersDataFromApi();
  }

  void toggleNearbyFilter() async {
    isNearbyFilterActive = !isNearbyFilterActive;
    print('Toggling nearby filter to: $isNearbyFilterActive');
    
    if (isNearbyFilterActive) {
      // Check location permission and get current location
      final hasPermission = await LocationService.instance.hasLocationPermission();
      if (!hasPermission) {
        // Request permission
        final position = await LocationService.instance.getCurrentLocation();
        if (position == null) {
          isNearbyFilterActive = false;
          print('Location permission denied or location unavailable');
          notifyListeners();
          return;
        }
        // If permission just granted and we got a position, update server now
        await profileApiService.updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    }
    
    _filterDto.page = 1;
    isFinishLoadMore = false;
    notifyListeners();
    getUsersDataFromApi();
  }

  void clearNearbyFilter() {
    isNearbyFilterActive = false;
    _filterDto.latitude = null;
    _filterDto.longitude = null;
    _filterDto.maxDistance = null;
    _filterDto.nearbyOnly = null;
    _filterDto.page = 1;
    isFinishLoadMore = false;
    notifyListeners();
    getUsersDataFromApi();
  }

  void openSearch() {
    isSearchOpen = true;
    searchFocusNode.requestFocus();
    notifyListeners();
  }

  void onSearchChanged(String query) {
    log('Search query received: "$query"');
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    // If query is empty or just whitespace, show all users
    if (query.trim().isEmpty) {
      log('Query is empty, loading all users');
      getData(); // This will reload all users
      return;
    }
    
    log('Starting search with debounce for query: "${query.trim()}"');
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      await vSafeApiCall<List<SSearchUser>>(
        onLoading: () async {
          setStateLoading();
          update();
        },
        onError: (exception, trace) {
          setStateError();
          update();
        },
        request: () async {
          _filterDto = UserFilterDto.init();
          _filterDto.fullName = query.trim(); // Trim whitespace from query
          _filterDto.gender = selectedGender; // Preserve gender filter during search
          _filterDto.profession = selectedProfession; // Preserve profession filter during search
          
          log('Search filter DTO: ${_filterDto.toMap()}');
          
          // Add location filter if nearby is active
          if (isNearbyFilterActive) {
            final position = await LocationService.instance.getCurrentLocation();
            if (position != null) {
              await profileApiService.updateLocation(
                latitude: position.latitude,
                longitude: position.longitude,
              );
              _filterDto.latitude = position.latitude;
              _filterDto.longitude = position.longitude;
              _filterDto.maxDistance = 50.0; // 50km radius
              _filterDto.nearbyOnly = true;
            }
          }
          
          isFinishLoadMore = false;
          final users = await profileApiService.appUsers(_filterDto);
          log('Search API returned ${users.length} users for query: "${query.trim()}"');
          return users;
        },
        onSuccess: (response) {
          setStateSuccess();
          data.clear();
          data.addAll(response);
        },
        ignoreTimeoutAndNoInternet: false,
      );
    });
  }

  Future getData() async {
    try {
      final oldUsers = VAppPref.getMap("api/users");
      log('----my old user-----${oldUsers}');
      if (oldUsers != null) {
        final list = oldUsers['data'] as List;
        final parsed = list.map((e) => SSearchUser.fromMap(e)).toList();
        // Shuffle cached users as well for a varied initial view
        parsed.shuffle(math.Random());
        value.data = parsed;
        setStateSuccess();
        update();
      }
    } catch (err) {
      if (kDebugMode) {
        print(err);
      }
    }
    await getUsersDataFromApi();
  }
}
