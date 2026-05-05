import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';

class ChatColorPickerPage extends StatefulWidget {
  final String roomId;
  final String? peerId;
  final Color currentColor;

  const ChatColorPickerPage({
    super.key,
    required this.roomId,
    required this.currentColor,
    this.peerId,
  });

  @override
  State<ChatColorPickerPage> createState() => _ChatColorPickerPageState();
}

class _ChatColorPickerPageState extends State<ChatColorPickerPage> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  Future<void> _applyColor() async {
    await ChatColorService.I.setColorForRoom(widget.roomId, _selectedColor);
    if (widget.peerId != null) {
      await ChatColorService.I.setColorForPeer(widget.peerId!, _selectedColor);
    }
    if (mounted) {
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Chat color updated',
      );
      Navigator.pop(context);
    }
  }

  Future<void> _resetToDefault() async {
    await ChatColorService.I.resetToDefault(widget.roomId, widget.peerId);
    if (mounted) {
      VAppAlert.showSuccessSnackBar(
        context: context,
        message: 'Reset to default color',
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : const Color(0xFFc9cfc8),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? CupertinoColors.black : const Color(0xFFc9cfc8),
        middle: const Text('Chat Color'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _applyColor,
          child: const Text('Apply'),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Color palette
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: ChatColorService.colorPalette.length,
                itemBuilder: (context, index) {
                  final color = ChatColorService.colorPalette[index];
                  final isSelected = color.value == _selectedColor.value;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              CupertinoIcons.check_mark,
                              color: _getContrastColor(color),
                              size: 32,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            // Reset button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFFB48648),
                  onPressed: _resetToDefault,
                  child: const Text(
                    'Reset to Default',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getContrastColor(Color backgroundColor) {
    // Calculate luminance and return black or white for best contrast
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
