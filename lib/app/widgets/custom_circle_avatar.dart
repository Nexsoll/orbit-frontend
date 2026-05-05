import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:badges/badges.dart' as badges;
import 'package:super_up_core/super_up_core.dart';

class CustomCircleAvatar extends StatelessWidget {
  final int radius;
  final String imageUrl;

  const CustomCircleAvatar({
    super.key,
    this.radius = 28,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final primaryUrl = _getCorrectImageUrl(imageUrl);
    final fallbackUrl = _getFallbackUrl(primaryUrl);

    return Container(
      width: radius * 2.0,
      height: radius * 2.0,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: primaryUrl.isEmpty
            ? const Icon(CupertinoIcons.person_2_fill, color: Colors.grey)
            : CachedNetworkImage(
                imageUrl: primaryUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) {
                  if (fallbackUrl.isEmpty || fallbackUrl == primaryUrl) {
                    return const Icon(CupertinoIcons.person_2_fill, color: Colors.grey);
                  }
                  return CachedNetworkImage(
                    imageUrl: fallbackUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const Icon(
                      CupertinoIcons.person_2_fill,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _getCorrectImageUrl(String imageUrl) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return '';
    // If it's already a full URL (starts with http/https), return as is
    if (trimmed.startsWith('http')) {
      return trimmed;
    }
    // If it already starts with /v-public/ or /media/, it's a server path - prepend base URL
    if (trimmed.startsWith('/v-public/') || trimmed.startsWith('/media/')) {
      return SConstants.baseMediaUrl + trimmed;
    }
    // Otherwise, assume it's a relative path and add /v-public/ prefix
    return SConstants.baseMediaUrl + '/v-public/' + trimmed;
  }

  String _getFallbackUrl(String url) {
    if (url.isEmpty) return '';
    // Swap between /v-public and /media if one 404s
    if (url.contains('/v-public/')) {
      return url.replaceFirst('/v-public/', '/media/');
    }
    if (url.contains('/media/')) {
      return url.replaceFirst('/media/', '/v-public/');
    }
    return url;
  }
}

class CustomCircleVerifiedAvatar extends StatelessWidget {
  final int radius;
  final String imageUrl;

  const CustomCircleVerifiedAvatar({
    super.key,
    this.radius = 28,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomCircleAvatar(
          imageUrl: imageUrl,
          radius: radius,
        ),
        PositionedDirectional(
          end: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
            child: const badges.Badge(
              badgeAnimation: badges.BadgeAnimation.fade(toAnimate: false),
              badgeContent: Icon(
                Icons.check,
                color: Colors.white,
                size: 7,
              ),
              badgeStyle: badges.BadgeStyle(
                shape: badges.BadgeShape.twitter,
                badgeColor: Colors.blue,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
