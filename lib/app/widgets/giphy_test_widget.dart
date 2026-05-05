import 'package:flutter/material.dart';
import 'package:v_chat_input_ui/v_chat_input_ui.dart';

/// Test widget to verify GIPHY sticker integration
class GiphyTestWidget extends StatefulWidget {
  const GiphyTestWidget({super.key});

  @override
  State<GiphyTestWidget> createState() => _GiphyTestWidgetState();
}

class _GiphyTestWidgetState extends State<GiphyTestWidget> {
  List<VSticker> _stickers = [];
  bool _isLoading = false;
  String _status = 'Ready to test GIPHY API';

  Future<void> _testGiphyConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing GIPHY connection...';
    });

    try {
      // Test trending stickers
      final trending = await GiphyStickerService.getTrendingStickers(limit: 10);
      
      if (trending.isNotEmpty) {
        setState(() {
          _stickers = trending;
          _status = 'Success! Loaded ${trending.length} trending stickers from GIPHY';
          _isLoading = false;
        });
      } else {
        setState(() {
          _status = 'No stickers returned from GIPHY API';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchStickers(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _status = 'Searching for "$query"...';
    });

    try {
      final results = await GiphyStickerService.searchStickers(
        query: query,
        limit: 15,
      );
      
      setState(() {
        _stickers = results;
        _status = 'Found ${results.length} stickers for "$query"';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Search error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GIPHY Sticker Test'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status and controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $_status',
                  style: TextStyle(
                    color: _status.startsWith('Error') ? Colors.red : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testGiphyConnection,
                      child: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Trending'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search stickers...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: _searchStickers,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Stickers grid
          Expanded(
            child: _stickers.isEmpty
                ? const Center(
                    child: Text(
                      'No stickers to display.\nTap "Test Trending" or search for stickers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: _stickers.length,
                    itemBuilder: (context, index) {
                      final sticker = _stickers[index];
                      return GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tapped: ${sticker.name}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: NetworkStickerWidget(
                                  sticker: sticker,
                                  size: 80,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  sticker.name,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
