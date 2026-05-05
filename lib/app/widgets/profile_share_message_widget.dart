import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/modules/peer_profile/views/peer_profile_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class ProfileShareMessageWidget extends StatelessWidget {
  final bool isMeSender;
  final Map<String, dynamic> data;

  const ProfileShareMessageWidget({
    super.key,
    required this.isMeSender,
    required this.data,
  });

  Map<String, dynamic> get _profileData {
    final inner = data['data'];
    if (inner is Map) {
      return Map<String, dynamic>.from(inner);
    }
    return data;
  }

  String get _userId =>
      (_profileData['userId'] ?? _profileData['id'] ?? _profileData['_id'] ?? '')
          .toString();

  String get _fullName =>
      (_profileData['fullName'] ?? _profileData['name'] ?? 'Profile').toString();

  String get _userImage =>
      (_profileData['userImage'] ?? _profileData['image'] ?? '').toString();

  String get _bio => (_profileData['bio'] ?? '').toString();

  String get _phoneNumber =>
      (_profileData['phoneNumber'] ?? _profileData['phone'] ?? '').toString();

  bool get _hasBadge {
    final value = _profileData['hasBadge'] ?? _profileData['isVerified'];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  Future<void> _openProfile(BuildContext context) async {
    if (_userId.isEmpty) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Profile is unavailable',
      );
      return;
    }
    await context.toPage(PeerProfileView(peerId: _userId));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03);
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProfile(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.person_crop_circle,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 6),
                Text(
                  'Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _userImage.isNotEmpty
                    ? VCircleAvatar(
                        vFileSource: VPlatformFile.fromUrl(networkUrl: _userImage),
                        radius: 22,
                      )
                    : const CircleAvatar(
                        radius: 22,
                        backgroundColor: CupertinoColors.systemGrey5,
                        child: Icon(
                          CupertinoIcons.person,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SUserNameWithBadge(
                        fullName: _fullName,
                        isVerified: _hasBadge,
                        textStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (_phoneNumber.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _phoneNumber,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      if (_bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.25,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: secondaryTextColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'View profile',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
