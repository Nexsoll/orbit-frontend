import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:super_up_core/super_up_core.dart';

import '../widgets/settings_list_item_tile.dart';
import '../../../../storage/views/manage_storage_page.dart';
import '../../../../storage/views/premium_upgrade_page.dart';
import '../../../../../core/services/user_files_service.dart';

class MediaStorageSettings extends StatefulWidget {
  const MediaStorageSettings({super.key});

  @override
  State<MediaStorageSettings> createState() => _MediaStorageSettingsState();
}

class _MediaStorageSettingsState extends State<MediaStorageSettings>
    with WidgetsBindingObserver {
  final _service = AutoDownloadMediaService();
  int dirSize = -1;

  Future<void> getDirSize() async {
    try {
      // Get all uploaded files from the server
      final files = await UserFilesService.getUserFiles(
        page: 1,
        limit: 1000, // Get all files
      );

      // Calculate total size from uploaded files
      int totalSize = 0;
      for (var file in files) {
        totalSize += file.fileSize;
      }

      dirSize = totalSize;
      setState(() {});
    } catch (e) {
      // If there's an error fetching files, set size to 0
      dirSize = 0;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getDirSize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh storage size when app comes back to foreground
      Future.delayed(const Duration(milliseconds: 300), () {
        getDirSize();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh storage when returning to this screen
    getDirSize();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false, // 👈 disables Hero animation
            largeTitle: Text(S.of(context).storageAndData),
          )
        ],
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    S
                        .of(context)
                        .chooseHowAutomaticDownloadWorks
                        .text
                        .color(Colors.grey),
                    const SizedBox(height: 8),
                    _buildStorageProgressBar(),
                  ],
                ),
              ),
              CupertinoListSection(
                dividerMargin: 0,
                topMargin: 10,
                additionalDividerMargin: 0,
                margin: EdgeInsets.zero,
                hasLeading: false,
                children: [
                  SettingsListItemTile(
                    color: Colors.grey.shade800,
                    title: S.of(context).whenUsingMobileData,
                    subtitle: _service
                        .getMediaDownloadOptionsForData()
                        .map((e) => _getTrans(e))
                        .toList()
                        .toString()
                        .replaceAll("[", "")
                        .replaceAll("]", "")
                        .text,
                    onTap: () => _onUpdateMobileData(
                      _service.getMediaDownloadOptionsForData(),
                    ),
                    icon: Icons.four_g_mobiledata,
                  ),
                  SettingsListItemTile(
                    color: Colors.grey.shade800,
                    title: S.of(context).whenUsingWifi,
                    subtitle: _service
                        .getMediaDownloadOptionsForWifi()
                        .map((e) => _getTrans(e))
                        .toList()
                        .toString()
                        .replaceAll("[", "")
                        .replaceAll("]", "")
                        .text,
                    onTap: () => _onUpdateWifiData(
                      _service.getMediaDownloadOptionsForWifi(),
                    ),
                    icon: CupertinoIcons.wifi,
                  ),
                  SettingsListItemTile(
                    color: Colors.grey.shade800,
                    title: "Manage Storage",
                    subtitle:
                        "View and delete files shared in chats to free up space"
                            .text,
                    onTap: _onManageStorage,
                    icon: CupertinoIcons.folder,
                  ),
                  SettingsListItemTile(
                    color: Colors.grey.shade800,
                    title: "Upgrade Plan",
                    subtitle: "Get more storage and premium features".text,
                    onTap: _onUpgradePlan,
                    icon: CupertinoIcons.star_fill,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTrans(MediaDownloadOptions data) {
    switch (data) {
      case MediaDownloadOptions.images:
        return S.of(context).image;
      case MediaDownloadOptions.videos:
        return S.of(context).video;
      case MediaDownloadOptions.files:
        return S.of(context).files;
    }
  }

  Future _onUpdateMobileData(
      List<MediaDownloadOptions> mediaDownloadOptionsForData) async {
    final res = await VAppAlert.chooseAlertDialog(
      context: context,
      inChoose: mediaDownloadOptionsForData,
    );
    await _service.updateMediaDownloadOptionsForData(options: res);
    setState(() {});
  }

  Future _onUpdateWifiData(
      List<MediaDownloadOptions> mediaDownloadOptionsForWifi) async {
    final res = await VAppAlert.chooseAlertDialog(
      context: context,
      inChoose: mediaDownloadOptionsForWifi,
    );
    await _service.updateMediaDownloadOptionsForWifi(options: res);
    setState(() {});
  }

  void _onManageStorage() async {
    await context.toPage(const ManageStoragePage());
    // Add a small delay to allow file system to update
    await Future.delayed(const Duration(milliseconds: 500));
    // Refresh storage size when returning from manage storage
    await getDirSize();
  }

  void _onUpgradePlan() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const PremiumUpgradePage(),
      ),
    );
  }

  Widget _buildStorageProgressBar() {
    if (dirSize == -1) {
      return const CupertinoActivityIndicator();
    }

    const double maxStorageBytes = 1024 * 1024 * 1024; // 1GB in bytes
    final double currentStorageBytes = dirSize.toDouble();
    final double progressValue =
        (currentStorageBytes / maxStorageBytes).clamp(0.0, 1.0);
    final String currentSizeText = _formatBytes(currentStorageBytes);
    final String maxSizeText = _formatBytes(maxStorageBytes);
    final double progressPercentage = progressValue * 100;

    Color progressColor;
    if (progressValue < 0.7) {
      progressColor = Colors.green;
    } else if (progressValue < 0.9) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "App storage size",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB48648), // app brown color
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.gift,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Free Plan",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              "$currentSizeText / $maxSizeText",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: CupertinoColors.systemGrey5,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${progressPercentage.toStringAsFixed(1)}% used",
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
    );
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) {
      return "${bytes.toStringAsFixed(0)} B";
    } else if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    } else if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    } else {
      return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
    }
  }
}
