// Copyright 2025, Orbit Chat
// ExploreChannelsView - lists all channel suggestions with follow/preview behavior

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:s_translation/generated/l10n.dart';

import '../../../../../core/models/channel/channel_suggestion.dart';
import '../controllers/story_tab_controller.dart';

class ExploreChannelsView extends StatefulWidget {
  const ExploreChannelsView({super.key});

  @override
  State<ExploreChannelsView> createState() => _ExploreChannelsViewState();
}

class _ExploreChannelsViewState extends State<ExploreChannelsView> {
  late final StoryTabController controller;

  @override
  void initState() {
    super.initState();
    controller = GetIt.I.get<StoryTabController>();
    // Ensure we have a larger dataset
    controller.getChannelSuggestions(limit: 50);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(
            CupertinoIcons.back,
            color: Colors.white,
            size: 26,
          ),
        ),
        middle: Text(S.of(context).exploreChannels),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: StreamBuilder<SLoadingState<StoryTabState>>(
            stream: controller.stream,
            builder: (context, snapshot) {
              final value = snapshot.data ?? controller.value;
              final items = value.data.channelSuggestions;

              if (value.loadingState == VChatLoadingState.loading) {
                return const Center(child: CupertinoActivityIndicator());
              }

              if (items.isEmpty) {
                return Center(
                  child: Text(
                    S.of(context).noChannelsToExploreNow,
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return _buildChannelTile(context, items[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTile(BuildContext context, ChannelSuggestion item) {
    return GestureDetector(
      onTap: () => controller.openChannelIfJoined(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: item.image.isNotEmpty ? NetworkImage(item.thumbImageS3) : null,
              child: item.image.isEmpty ? const Icon(CupertinoIcons.person_2_fill) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.followers} ${S.of(context).followersLabel}',
                    style: context.cupertinoTextTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!item.isJoined)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: const Color(0xFFB48648),
                onPressed: () => controller.joinAndOpenChannel(context, item),
                child: Text(
                  S.of(context).follow,
                  style: const TextStyle(color: Colors.white),
                ),
              )
          ],
        ),
      ),
    );
  }
}
