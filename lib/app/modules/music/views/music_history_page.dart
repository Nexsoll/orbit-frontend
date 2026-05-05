import 'package:flutter/cupertino.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class MusicHistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> historyItems;
  final Future<void> Function()? onClearHistory;

  const MusicHistoryPage({
    super.key,
    required this.historyItems,
    this.onClearHistory,
  });

  @override
  State<MusicHistoryPage> createState() => _MusicHistoryPageState();
}

class _MusicHistoryPageState extends State<MusicHistoryPage> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.historyItems);
  }

  IconData _iconFor(Map<String, dynamic> item) {
    final type = (item['mediaType'] ?? '').toString().toLowerCase();
    if (type == 'audio') return CupertinoIcons.music_note_2;
    if (type == 'video') return CupertinoIcons.play_rectangle;
    return CupertinoIcons.doc_text;
  }

  String _seenAtLabel(Map<String, dynamic> item) {
    final raw = (item['seenAt'] ?? '').toString();
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hh:$mm';
  }

  Future<void> _clearHistory() async {
    if (widget.onClearHistory != null) {
      await widget.onClearHistory!.call();
    }
    if (!mounted) return;
    setState(() {
      _items.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('History'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 30,
          onPressed: _items.isEmpty ? null : _clearHistory,
          child: const Text(
            'Clear',
            style: TextStyle(
              color: Color(0xFFB48648),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: _items.isEmpty
            ? const Center(
                child: Text(
                  'No history yet',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 15,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _items.length,
                separatorBuilder: (_, __) => Container(
                  height: 1,
                  color: CupertinoColors.separator,
                ),
                itemBuilder: (_, i) {
                  final h = _items[i];
                  final title = (h['title'] ?? 'Untitled').toString().trim();
                  final uploader =
                      (h['uploaderData']?['fullName'] ?? '').toString();
                  final uploaderImg =
                      (h['uploaderData']?['userImage'] ?? '').toString();
                  final seenAt = _seenAtLabel(h);

                  return CupertinoListTile.notched(
                    title: Text(
                      title.isEmpty ? 'Untitled' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (uploader.isNotEmpty) uploader,
                        if (seenAt.isNotEmpty) 'Seen $seenAt',
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: uploaderImg.isNotEmpty
                        ? VCircleAvatar(
                            radius: 16,
                            vFileSource: VPlatformFile.fromUrl(
                              networkUrl: uploaderImg,
                            ),
                          )
                        : Icon(
                            _iconFor(h),
                            color: const Color(0xFFB48648),
                          ),
                    onTap: () => Navigator.of(context).pop(h),
                  );
                },
              ),
      ),
    );
  }
}
