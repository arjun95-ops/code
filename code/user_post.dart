import 'package:mychatolic_app/models/profile.dart';

class UserPost {
  final String id;
  final String userId;
  final String? caption;
  final String? imageUrl;
  final String type;
  final DateTime createdAt;
  
  // Dynamic UI Fields
  final int likesCount;
  final int commentsCount;
  final String? content; // Legacy field syncing with caption
  final Profile? author;
  final bool isLikedByMe;

  UserPost({
    required this.id,
    required this.userId,
    this.caption,
    this.imageUrl,
    required this.type,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.content,
    this.author,
    this.isLikedByMe = false,
  });

  /// CopyWith Method - Critical for State Management
  /// Allows updating specific fields (like likesCount) without losing other data (like author).
  UserPost copyWith({
    String? id,
    String? userId,
    String? caption,
    String? imageUrl,
    String? type,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    String? content,
    Profile? author,
    bool? isLikedByMe,
  }) {
    return UserPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      content: content ?? this.content ?? (caption ?? this.caption),
      // Important: Preserve existing author if not provided
      author: author ?? this.author,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }

  factory UserPost.fromJson(Map<String, dynamic> json) {
    // 1. Image Logic
    String? img = json['image_url'];
    if (img == null || img.isEmpty) {
      img = json['content_url'];
    }

    // 2. Type Logic
    String postType = (img != null && img.isNotEmpty) 
        ? 'photo' 
        : (json['type'] ?? 'text');

    return UserPost(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      caption: json['caption'],
      imageUrl: img,
      type: postType,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      content: json['caption'] ?? json['content'],
      isLikedByMe: json['is_liked_by_me'] ?? false,
      
      // Robust Author Parsing
      author: json['profiles'] != null 
          ? Profile.fromJson(json['profiles'])
          : Profile(
              id: json['user_id']?.toString() ?? '',
              fullName: json['author_name'] ?? 'Umat', // Fallback for RPC results
              role: 'Umat'
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'caption': caption,
      'image_url': imageUrl,
      'type': type,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
