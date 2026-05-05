// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:loadmore/loadmore.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/widgets/app_logo.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_platform/v_platform.dart';

import '../../../../../core/app_config/app_config_controller.dart';
import '../controllers/users_tab_controller.dart';

class UsersTabView extends StatefulWidget {
  const UsersTabView({super.key});

  @override
  State<UsersTabView> createState() => _UsersTabViewState();
}

class _UsersTabViewState extends State<UsersTabView> {
  late final UsersTabController controller;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<UsersTabController>();
    controller.onInit();
  }

  void _showProfessionFilter(BuildContext context) {
    final professions =
        VAppConfigController.appConfig.professions ?? SConstants.commonProfessions;
    VAppAlert.showModalSheetWithActions(
      title: 'Filter by Profession',
      context: context,
      content: [
        ModelSheetItem(title: 'All', id: 'all'),
        ...professions.map(
          (p) => ModelSheetItem(title: p, id: p),
        ),
      ],
    ).then((res) {
      if (res == null) return;
      if (res.id == 'all') {
        controller.clearProfessionFilter();
      } else {
        controller.updateProfessionFilter(res.id);
      }
    });
  }

  void _showFilterOptions(BuildContext context) {
    VAppAlert.showModalSheetWithActions(
      title: 'Filter Options',
      context: context,
      content: [
        ModelSheetItem(
          title: 'Filter by Gender',
          id: 'gender',
          iconData: const Icon(CupertinoIcons.person_2),
        ),
        ModelSheetItem(
          title: 'Filter by Profession',
          id: 'profession',
          iconData: const Icon(CupertinoIcons.briefcase),
        ),
        ModelSheetItem(
          title: controller.isNearbyFilterActive ? 'Disable Nearby Users' : 'Show Nearby Users',
          id: 'nearby',
          iconData: const Icon(CupertinoIcons.location),
        ),
      ],
    ).then((res) {
      if (res == null) return;
      if (res.id == 'gender') {
        _showGenderFilter(context);
      } else if (res.id == 'profession') {
        _showProfessionFilter(context);
      } else if (res.id == 'nearby') {
        controller.toggleNearbyFilter();
      }
    });
  }

  void _showGenderFilter(BuildContext context) {
    VAppAlert.showModalSheetWithActions(
      title: 'Filter by Gender',
      context: context,
      content: [
        ModelSheetItem(title: 'All', id: 'all'),
        ModelSheetItem(title: 'Male', id: 'male'),
        ModelSheetItem(title: 'Female', id: 'female'),
        ModelSheetItem(title: 'Other', id: 'other'),
      ],
    ).then((res) {
      if (res == null) return;
      switch (res.id) {
        case 'all':
          controller.clearGenderFilter();
          break;
        case 'male':
          controller.updateGenderFilter('male');
          break;
        case 'female':
          controller.updateGenderFilter('female');
          break;
        case 'other':
          controller.updateGenderFilter('other');
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            CupertinoSliverNavigationBar(
              transitionBetweenRoutes: false, // 👈 disables Hero animation
              largeTitle: Text(S.of(context).users,
                  style: context.cupertinoTextTheme.textStyle.copyWith(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                  )),
              trailing: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, child) {
                  if (controller.isSearchOpen) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoSearchTextField(
                              controller: controller.searchController,
                              onChanged: controller.onSearchChanged,
                              focusNode: controller.searchFocusNode,
                            ),
                          ),
                          TextButton(
                            onPressed: controller.closeSearch,
                            child: Text(S.of(context).close),
                          )
                        ],
                      ),
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _showFilterOptions(context),
                        child: Stack(
                          children: [
                            const Icon(
                              CupertinoIcons.slider_horizontal_3,
                              size: 28,
                              color: Color(0xFFB48648),
                            ),
                            if (controller.selectedGender != null || controller.isNearbyFilterActive || controller.selectedProfession != null)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: controller.openSearch,
                        child: const Icon(
                          CupertinoIcons.search,
                          size: 28,
                          color: Color(0xFFB48648),
                        ),
                      ),
                    ],
                  );
                },
              ),
              middle: const AppLogo(),
            )
          ];
        },
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              AdsBannerWidget(
                adsId: VPlatforms.isAndroid
                    ? SConstants.androidBannerAdsUnitId
                    : SConstants.iosBannerAdsUnitId,
                isEnableAds: VAppConfigController.appConfig.enableAds,
              ),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, child) {
                  if (controller.selectedGender != null) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey.shade300,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.slider_horizontal_3, 
                               size: 16, 
                               color: Colors.grey.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Gender: ${controller.selectedGender![0].toUpperCase()}${controller.selectedGender!.substring(1)}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: controller.clearGenderFilter,
                            child: Icon(
                              CupertinoIcons.clear_circled_solid,
                              size: 20,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, child) {
                  if (controller.selectedProfession != null) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey.shade300,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.briefcase, 
                               size: 16, 
                               color: Colors.grey.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Profession: ${controller.selectedProfession}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: controller.clearProfessionFilter,
                            child: Icon(
                              CupertinoIcons.clear_circled_solid,
                              size: 20,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              Expanded(
                child: ValueListenableBuilder<SLoadingState<List<SSearchUser>>>(
                  valueListenable: controller,
                  builder: (_, value, __) {
                    return VAsyncWidgetsBuilder(
                      loadingState: value.loadingState,
                      onRefresh: controller.getUsersDataFromApi,
                      successWidget: () {
                        return RefreshIndicator(
                          onRefresh: controller.getUsersDataFromApi,
                          child: LoadMore(
                            onLoadMore: controller.onLoadMore,
                            isFinish: controller.isFinishLoadMore,
                            textBuilder: (status) => "",
                            child: ListView.separated(
                              cacheExtent: 300,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              itemBuilder: (context, index) {
                                final item = controller.data[index];
                                return SUserItem(
                                  onTap: () =>
                                      controller.onItemPress(item, context),
                                  baseUser: item.baseUser,
                                  hasBadge: item.hasBadge,
                                  subtitle: item.getUserBio,
                                  distance: item.distance,
                                  trailing: const Icon(
                                    CupertinoIcons.forward,
                                    color: Color(0xFFB48648),
                                  ),
                                );
                              },
                              itemCount: controller.data.length,
                              separatorBuilder: (context, index) {
                                return Divider(
                                  height: 10,
                                  thickness: 1,
                                  color: Colors.grey.withOpacity(.2),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
