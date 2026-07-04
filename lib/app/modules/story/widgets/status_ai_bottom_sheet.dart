import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up_core/super_up_core.dart';
import '../../../core/api_service/status_ai/status_ai_api_service.dart';
import '../../../core/models/story/status_ai_models.dart';
import '../../../core/utils/enums.dart';

class StatusAiBottomSheet extends StatefulWidget {
  final StoryType storyType;
  final String? initialText;
  final String? mimeType;
  final VPlatformFile? mediaFile;
  final Function(String) onSuggestionSelected;

  const StatusAiBottomSheet({
    Key? key,
    required this.storyType,
    this.initialText,
    this.mimeType,
    this.mediaFile,
    required this.onSuggestionSelected,
  }) : super(key: key);

  @override
  State<StatusAiBottomSheet> createState() => _StatusAiBottomSheetState();

  static void show(
    BuildContext context, {
    required StoryType storyType,
    String? initialText,
    String? mimeType,
    VPlatformFile? mediaFile,
    required Function(String) onSuggestionSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatusAiBottomSheet(
        storyType: storyType,
        initialText: initialText,
        mimeType: mimeType,
        mediaFile: mediaFile,
        onSuggestionSelected: onSuggestionSelected,
      ),
    );
  }
}

class _StatusAiBottomSheetState extends State<StatusAiBottomSheet> {
  late final StatusAiApiService _apiService;
  bool _isLoading = true;
  String? _error;
  StatusAiSuggestionResult? _suggestions;

  @override
  void initState() {
    super.initState();
    if (!GetIt.I.isRegistered<StatusAiApiService>()) {
      GetIt.I.registerSingleton<StatusAiApiService>(StatusAiApiService.init());
    }
    _apiService = GetIt.I.get<StatusAiApiService>();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _apiService.getSuggestions(
        StatusAiSuggestionsDto(
          storyType: widget.storyType.name,
          text: widget.initialText,
          mimeType: widget.mimeType,
        ),
        mediaFile: widget.mediaFile,
      );
      setState(() {
        _suggestions = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load AI suggestions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AI Suggestions ✨',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _error != null
                    ? _buildError()
                    : _buildSuggestionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSuggestions,
            child: const Text('Retry'),
          )
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_suggestions == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_suggestions!.captions.isNotEmpty) ...[
          const Text(
            'Captions',
            style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._suggestions!.captions.map((c) => _buildSuggestionCard(c)),
          const SizedBox(height: 16),
        ],
        if (_suggestions!.hashtags.isNotEmpty) ...[
          const Text(
            'Hashtags',
            style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions!.hashtags.map((h) => _buildChip(h)).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (_suggestions!.emojis.isNotEmpty) ...[
          const Text(
            'Emojis',
            style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions!.emojis.map((e) => _buildChip(e)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionCard(String text) {
    return Card(
      color: Colors.white12,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          widget.onSuggestionSelected(text);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String text) {
    return ActionChip(
      backgroundColor: Colors.white12,
      labelStyle: const TextStyle(color: Colors.white),
      label: Text(text),
      onPressed: () {
        widget.onSuggestionSelected(text);
        Navigator.of(context).pop();
      },
    );
  }
}
