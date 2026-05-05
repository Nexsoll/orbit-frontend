// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:s_translation/generated/l10n.dart';
import 'package:v_chat_room_page/v_chat_room_page.dart';

import '../controllers/chats_search_controller.dart';

class ChatsSearchView extends StatefulWidget {
  const ChatsSearchView({super.key});

  @override
  State<ChatsSearchView> createState() => _ChatsSearchViewState();
}

class _ChatsSearchViewState extends State<ChatsSearchView> {
  late final ChatsSearchController controller;

  @override
  void initState() {
    super.initState();
    controller = ChatsSearchController();
    controller.onInit();
  }

  @override
  void dispose() {
    controller.onClose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false, // 👈 disables Hero animation

        automaticallyImplyLeading: false,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            S.of(context).cancel,
            style: const TextStyle(
              color: CupertinoColors.activeBlue,
            ),
          ),
        ),
        middle: CupertinoSearchTextField(
          placeholder: S.of(context).search,
          controller: controller.searchController,
          focusNode: controller.searchFocusNode,
          onChanged: (value) {
            controller.onSearch(value);
          },
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, child) {
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: controller.data.length,
              itemBuilder: (context, index) {
                final room = controller.data[index];
                return VRoomItem(
                  room: room,
                  onRoomItemPress: (room) =>
                      controller.onRoomItemPress(room, context),
                  onRoomItemLongPress: (room) {},
                );
              },
            );
          },
        ),
      ),
    );
  }
}
