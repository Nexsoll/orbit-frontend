import 'package:flutter/material.dart';
import 'package:v_chat_message_page/v_chat_message_page.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import '../../../core/services/ai_assistant_state.dart';
import '../../../../v_chat_v2/translations.dart';

class AiAssistantPage extends StatefulWidget {
  final VRoom vRoom;

  const AiAssistantPage({
    super.key,
    required this.vRoom,
  });

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final AiAssistantState _aiState = AiAssistantState();

  @override
  Widget build(BuildContext context) {
    final messageConfig = VMessageConfig(
      isCallsAllowed: false,
      isSendMediaAllowed: true,
      isEnableAds: false,
      showDisconnectedWidget: false,
      maxMediaSize: 1024 * 1024 * 50,
      compressImageQuality: 55,
      maxRecordTime: const Duration(minutes: 30),
      onMessageLongPress: null, // Enable default long press behavior for forwarding
    );

    return Scaffold(
      body: _CustomAISingleView(
        vMessageConfig: messageConfig,
        vRoom: widget.vRoom,
        language: vMessageLocalizationPageModel(context),
        aiState: _aiState,
      ),
    );
  }
}

class _CustomAISingleView extends StatefulWidget {
  final VMessageConfig vMessageConfig;
  final VRoom vRoom;
  final VMessageLocalization language;
  final AiAssistantState aiState;

  const _CustomAISingleView({
    required this.vMessageConfig,
    required this.vRoom,
    required this.language,
    required this.aiState,
  });

  @override
  State<_CustomAISingleView> createState() => _CustomAISingleViewState();
}

class _CustomAISingleViewState extends State<_CustomAISingleView> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VSingleView(
          vMessageConfig: widget.vMessageConfig,
          vRoom: widget.vRoom,
          language: widget.language,
        ),
        // Search icon positioned in the top right
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: ListenableBuilder(
            listenable: widget.aiState,
            builder: (context, child) {
              return GestureDetector(
                onTap: () {
                  widget.aiState.toggleWebSearch();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.aiState.isWebSearchEnabled
                            ? 'Web search enabled'
                            : 'Web search disabled',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.aiState.isWebSearchEnabled
                        ? const Color(0xFFB48648).withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.language,
                    color: widget.aiState.isWebSearchEnabled
                        ? const Color(0xFFB48648)
                        : Colors.grey,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
