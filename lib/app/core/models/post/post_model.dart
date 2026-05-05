enum PostType {
  text,
  image,
  video,
  reel,
  location,
}

class PostModel {
  final String id;
  final String userId;
  final PostType postType;
  final String caption;
  final List<String> mentionedUserIds;
  final List<String> hashtags;
  final PostMedia? media;
  /// Multiple image URLs for photo posts
  final List<String> mediaUrls;
  final PostLocation? location;
  final int likesCount;
  final int viewsCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isReel;
  final String createdAt;
  final PostAuthor author;

  const PostModel({
    required this.id,
    required this.userId,
    required this.postType,
    required this.caption,
    required this.mentionedUserIds,
    required this.hashtags,
    this.media,
    this.mediaUrls = const [],
    this.location,
    required this.likesCount,
    required this.viewsCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isLiked,
    required this.isReel,
    required this.createdAt,
    required this.author,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    final user = map['userId'] is Map ? map['userId'] : {};
    return PostModel(
      id: map['_id'] ?? map['id'] ?? '',
      userId: map['userId'] is String
          ? map['userId']
          : (user['_id'] ?? user['id'] ?? ''),
      postType: PostType.values.firstWhere(
        (e) => e.name == (map['postType'] ?? 'text'),
        orElse: () => PostType.text,
      ),
      caption: map['caption'] ?? '',
      mentionedUserIds:
          (map['mentionedUsers'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      hashtags:
          (map['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      media: map['media'] != null ? PostMedia.fromMap(map['media']) : null,
      mediaUrls: (map['mediaUrls'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      location: map['location'] != null
          ? PostLocation.fromMap(map['location'])
          : null,
      likesCount: map['likesCount'] ?? 0,
        viewsCount: (map['viewsCount'] as num?)?.toInt() ??
          (map['viewCount'] as num?)?.toInt() ??
          ((map['views'] is List)
            ? (map['views'] as List).length
            : (map['views'] as num?)?.toInt() ?? 0),
      commentsCount: map['commentsCount'] ?? 0,
      sharesCount: map['sharesCount'] ?? 0,
      isLiked: (map['likedBy'] as List?)
              ?.any((e) => e.toString() == map['currentUserId']) ??
          false,
      isReel: map['isReel'] ?? false,
      createdAt: map['createdAt'] ?? '',
      author: PostAuthor(
        id: user['_id'] ?? user['id'] ?? '',
        fullName: user['fullName'] ?? '',
        userImage: user['userImage'] ?? '',
        username: user['username'] ?? '',
        isFollowing: user['isFollowing'] == true,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'userId': userId,
      'postType': postType.name,
      'caption': caption,
      'mentionedUsers': mentionedUserIds,
      'hashtags': hashtags,
      'media': media?.toMap(),
      'mediaUrls': mediaUrls,
      'location': location?.toMap(),
      'likesCount': likesCount,
      'viewsCount': viewsCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'isReel': isReel,
      'createdAt': createdAt,
      'author': author.toMap(),
    };
  }
}

class PostMedia {
  final String? url;
  final String? thumbnail;
  final String? mimeType;
  final int? fileSize;
  final int? duration;
  final double? width;
  final double? height;

  const PostMedia({
    this.url,
    this.thumbnail,
    this.mimeType,
    this.fileSize,
    this.duration,
    this.width,
    this.height,
  });

  factory PostMedia.fromMap(Map<String, dynamic> map) {
    return PostMedia(
      url: (map['url'] ?? map['mediaUrl'] ?? '').toString(),
      thumbnail: (map['thumbnail'] ?? map['thumbUrl'] ?? map['thumbnailUrl'] ?? '').toString(),
      mimeType: (map['mimeType'] ?? map['type'] ?? '').toString(),
      fileSize: map['fileSize'],
      duration: map['duration'],
      width: map['width']?.toDouble(),
      height: map['height']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'thumbnail': thumbnail,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'duration': duration,
      'width': width,
      'height': height,
    };
  }
}

class PostLocation {
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? placeName;

  const PostLocation({
    this.latitude,
    this.longitude,
    this.address,
    this.placeName,
  });

  factory PostLocation.fromMap(Map<String, dynamic> map) {
    return PostLocation(
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      address: map['address'],
      placeName: map['placeName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'placeName': placeName,
    };
  }
}

class PostAuthor {
  final String id;
  final String fullName;
  final String userImage;
  final String username;
  final bool isFollowing;

  const PostAuthor({
    required this.id,
    required this.fullName,
    required this.userImage,
    required this.username,
    this.isFollowing = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'userImage': userImage,
      'username': username,
      'isFollowing': isFollowing,
    };
  }
}
