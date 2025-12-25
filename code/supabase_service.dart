import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/models/schedule.dart';
import 'package:mychatolic_app/models/article.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/models/comment.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'dart:io';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // --- REAL-TIME POST STREAM (EVENT BUS) ---
  static final StreamController<UserPost> _postStream = StreamController.broadcast();
  static Stream<UserPost> get postUpdateStream => _postStream.stream;

  static void broadcastPostUpdate(UserPost post) {
    if (!_postStream.isClosed) {
       _postStream.add(post);
    }
  }

  // --- AUTH ---
  User? get currentUser => _supabase.auth.currentUser;

  // 1. Fetch Countries
  Future<List<Country>> fetchCountries() async {
    try {
      final response = await _supabase.from('countries').select().order('name', ascending: true);
      final data = response as List<dynamic>;
      return data.map((json) => Country.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch countries: $e');
    }
  }

  // 2. Fetch Dioceses
  Future<List<Diocese>> fetchDioceses(String countryId) async {
    try {
      final response = await _supabase
          .from('dioceses')
          .select()
          .eq('country_id', countryId)
          .order('name', ascending: true);
      final data = response as List<dynamic>;
      return data.map((json) => Diocese.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch dioceses: $e');
    }
  }

  // 3. Fetch Churches
  Future<List<Church>> fetchChurches(String dioceseId) async {
    try {
      final response = await _supabase
          .from('churches')
          .select()
          .eq('diocese_id', dioceseId)
          .order('name', ascending: true);
      final data = response as List<dynamic>;
      return data.map((json) => Church.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch churches: $e');
    }
  }

  // 4. Fetch Schedules
  Future<List<Schedule>> fetchSchedules(String churchId) async {
    try {
      final response = await _supabase
          .from('mass_schedules')
          .select()
          .eq('church_id', churchId)
          .order('day_of_week', ascending: true)
          .order('time_start', ascending: true);
      
      final data = response as List<dynamic>;
      return data.map((json) => Schedule.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch schedules: $e');
    }
  }

  // 4b. Create Radar from Schedule
  Future<void> createRadarFromSchedule({
    required String scheduleId,
    required String notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      final scheduleData = await _supabase
          .from('mass_schedules')
          .select('church_id, time_start, day_of_week')
          .eq('id', scheduleId)
          .single();

      final churchId = scheduleData['church_id'];
      final timeStart = scheduleData['time_start'] as String;
      final dayOfWeek = scheduleData['day_of_week'] as int;

      final now = DateTime.now();
      int currentDayDb = (now.weekday == 7) ? 0 : now.weekday; 
      
      int daysToAdd = (dayOfWeek - currentDayDb + 7) % 7;
      final parts = timeStart.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (daysToAdd == 0) {
         final timeNow = now.hour * 60 + now.minute;
         final timeMass = hour * 60 + minute;
         if (timeNow > timeMass) daysToAdd = 7;
      }

      final scheduleTime = DateTime(now.year, now.month, now.day + daysToAdd, hour, minute);

      await _supabase.from('radars').insert({
        'user_id': user.id,
        'type': 'mass',
        'visibility': 'public',
        'status': 'active',
        'title': 'Misa Bersama',
        'description': notes,
        'church_id': churchId,
        'schedule_time': scheduleTime.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      print("Failed to create mass radar: $e");
      throw Exception("Gagal membuat radar jadwal: $e");
    }
  }

  // 5. Fetch Latest Articles
  Future<List<Article>> fetchLatestArticles() async {
    try {
      final response = await _supabase
          .from('articles')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(20); 
      final data = response as List<dynamic>;
      return data.map((json) => Article.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch articles: $e');
    }
  }

  // 5b. Fetch Single Post by ID (For Detail Freshness)
  Future<UserPost?> fetchPostById(String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    try {
      // 1. Fetch Post Data
      final postData = await _supabase.from('posts').select().eq('id', postId).single();
      
      // 2. Fetch Author Profile
      final authorId = postData['user_id'];
      final authorData = await _supabase.from('profiles').select().eq('id', authorId).single();
      final authorProfile = Profile(
        id: authorId, 
        fullName: authorData['full_name'] ?? 'Umat', 
        avatarUrl: authorData['avatar_url'], 
        role: authorData['role'] ?? 'Umat'
      );

      // 3. Fetch Counts & Status
      final likesCount = await _supabase.from('post_likes').count().eq('post_id', postId);
      final commentsCount = await _supabase.from('post_comments').count().eq('post_id', postId);
      
      bool isLiked = false;
      if (userId != null) {
        final likeCheck = await _supabase.from('post_likes').select('id').eq('post_id', postId).eq('user_id', userId).maybeSingle();
        isLiked = likeCheck != null;
      }

      return UserPost(
        id: postData['id'].toString(),
        userId: authorId,
        caption: postData['caption'],
        imageUrl: postData['image_url'],
        type: postData['type'] ?? 'text',
        createdAt: DateTime.tryParse(postData['created_at'].toString()) ?? DateTime.now(),
        likesCount: likesCount,
        commentsCount: commentsCount,
        isLikedByMe: isLiked,
        author: authorProfile,
      );
    } catch (e) {
      print("Error fetching single post: $e");
      return null;
    }
  }

  // 6. Fetch Posts RPC
  Future<List<UserPost>> fetchPosts({
    String? filterType, 
    String? filterId, 
    String? userId,
    int page = 0,
    int limit = 20,
  }) async {
    // Use passed userId or fallback to current authenticated user
    final currentUserId = userId ?? _supabase.auth.currentUser?.id;
    print("Fetching posts via RPC... User: $currentUserId, Page: $page");

    try {
      final Map<String, dynamic> params = {
        'p_user_id': currentUserId,
        'p_filter_type': filterType,
        'p_filter_id': filterId,
        'p_limit': limit,
        'p_offset': page * limit,
      };

      final response = await _supabase.rpc('get_posts_with_status', params: params);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
         // Correct Mapping based on user request
         final authorProfile = Profile(
            id: json['user_id']?.toString() ?? '',
            fullName: json['author_full_name'] ?? 'Umat', 
            avatarUrl: json['author_avatar_url'], 
            role: json['author_role'] ?? 'Umat',
         );

         return UserPost(
           id: json['id'].toString(),
           userId: json['user_id'].toString(),
           caption: json['caption'],
           imageUrl: json['image_url'],
           type: json['type'] ?? 'text',
           createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
           likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
           commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
           isLikedByMe: json['is_liked_by_me'] ?? false, 
           author: authorProfile,
         );
      }).toList();

    } catch (e, stackTrace) {
      print("RPC FETCH ERROR: $e");
      print(stackTrace);
      throw Exception('Failed to fetch posts: $e');
    }
  }

  // 7. Create Post
  Future<void> createPost({
    required String content, 
    String? imageUrl, 
    required String type,
    String? countryId,
    String? dioceseId,
    String? churchId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('posts').insert({
        'user_id': user.id,
        'caption': content,
        'image_url': imageUrl,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
        'country_id': countryId,
        'diocese_id': dioceseId,
        'church_id': churchId,
      });
    } catch (e) {
      throw Exception("Post creation failed: $e");
    }
  }

  // Helper: Upload Post Image
  Future<String> uploadPostImage(File image) async {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      try {
        await _supabase.storage.from('post_images').upload(
          fileName,
          image,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        return _supabase.storage.from('post_images').getPublicUrl(fileName);
      } catch (e) {
        throw Exception("Image upload failed: $e");
      }
  }

  // 8. Toggle Like
  Future<bool> toggleLike(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final check = await _supabase
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (check != null) {
        await _supabase.from('post_likes').delete().eq('id', check['id']);
        return false;
      } else {
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
        return true;
      }
    } catch (e) {
      throw Exception("Toggle like failed: $e");
    }
  }

  // 9. Fetch Notifications
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    try {
      // Mock notifications for now
      return [];
    } catch (e) {
      return [];
    }
  }

  // 10. Search Locations
  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.isEmpty) return [];
    
    try {
      List<Future<dynamic>> searchTasks = [
        _supabase.from('countries').select('id, name').ilike('name', '%$query%').limit(5),
        _supabase.from('dioceses').select('id, name').ilike('name', '%$query%').limit(5),
        _supabase.from('churches').select('id, name').ilike('name', '%$query%').limit(5),
      ];

      final results = await Future.wait(searchTasks);
      
      final countries = (results[0] as List<dynamic>).map((e) => {
        'id': e['id'].toString(), 
        'name': e['name'] as String, 
        'type': 'country', 
      }).toList();
      
      final dioceses = (results[1] as List<dynamic>).map((e) => {
        'id': e['id'].toString(), 
        'name': e['name'] as String, 
        'type': 'diocese', 
      }).toList();
      
      final churches = (results[2] as List<dynamic>).map((e) => {
        'id': e['id'].toString(), 
        'name': e['name'] as String, 
        'type': 'church', 
      }).toList();

      return [...countries, ...dioceses, ...churches];
    } catch (e) {
      print("Search Error: $e");
      return [];
    }
  }

  // 11. Fetch Comments
  Future<List<Comment>> fetchComments(String postId) async {
    final currentUser = _supabase.auth.currentUser;

    try {
      final response = await _supabase
          .from('post_comments')
          .select('*, profiles(*), comment_likes(user_id)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      
      final data = response as List<dynamic>;

      final List<Comment> allComments = [];
      for (var json in data) {
        try {
          final likesList = json['comment_likes'] as List<dynamic>? ?? [];
          final isLiked = currentUser != null && likesList.any((l) => l['user_id'] == currentUser.id);

          final map = Map<String, dynamic>.from(json);
          map['likes_count'] = likesList.length;
          map['is_liked_by_me'] = isLiked;
          
          final comment = Comment.fromJson(map);
          allComments.add(comment);
        } catch (e) {
          print("Error parsing comment: $e");
        }
      }

      final Map<String, List<Comment>> childrenMap = {};
      for (var c in allComments) {
        if (c.parentId != null) {
          if (!childrenMap.containsKey(c.parentId!)) {
            childrenMap[c.parentId!] = [];
          }
          childrenMap[c.parentId!]!.add(c);
        }
      }

      Comment buildTree(Comment c) {
        final children = childrenMap[c.id] ?? [];
        return Comment(
          id: c.id,
          userId: c.userId,
          content: c.content,
          createdAt: c.createdAt,
          author: c.author,
          parentId: c.parentId,
          replies: children.map((child) => buildTree(child)).toList(),
          likesCount: c.likesCount,
          isLikedByMe: c.isLikedByMe,
        );
      }

      final List<Comment> rootComments = [];
      for (var c in allComments) {
        if (c.parentId == null) {
          rootComments.add(buildTree(c));
        }
      }
      return rootComments;

    } catch (e, stack) {
      print("Failed to fetch comments: $e");
      print(stack);
      return [];
    }
  }

  // 12. Add Comment
  Future<void> addComment(String postId, String content, {String? parentId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
        'parent_id': parentId,
      });
    } catch (e) {
      throw Exception("Failed to add comment: $e");
    }
  }

  // 12b. Toggle Comment Like
  Future<bool> toggleCommentLike(String commentId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
       final check = await _supabase
           .from('comment_likes')
           .select('id')
           .eq('comment_id', commentId)
           .eq('user_id', user.id)
           .maybeSingle();

       if (check != null) {
         await _supabase.from('comment_likes').delete().eq('id', check['id']);
         return false; 
       } else {
         await _supabase.from('comment_likes').insert({
           'comment_id': commentId,
           'user_id': user.id,
         });
         return true;
       }
    } catch (e) {
      throw Exception("Like comment failed: $e");
    }
  }

  // 12c. Report Comment
  Future<void> reportComment(String commentId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    try {
      await _supabase.from('comment_reports').insert({
        'comment_id': commentId,
        'reporter_id': user.id,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
       throw Exception("Report comment failed: $e");
    }
  }

  // 13. Start Chat
  Future<String> startChat(String otherUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) throw Exception("Not logged in");

    try {
      final response = await _supabase
          .from('social_chats')
          .select('id')
          .contains('participants', [myId, otherUserId])
          .maybeSingle();

      if (response != null) {
        return response['id'] as String;
      }
    } catch (e) {}

    try {
      final newChat = await _supabase.from('social_chats').insert({
        'participants': [myId, otherUserId],
        'last_message': "Memulai percakapan",
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      return newChat['id'] as String;
    } catch (e) {
      throw Exception("Failed to start chat: $e");
    }
  }

  // 14. Report Post
  Future<void> reportPost(String postId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('post_reports').insert({
        'post_id': postId,
        'reporter_id': user.id,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Report failed: $e");
    }
  }

  // 15. Delete Post
  Future<void> deletePost(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      throw Exception("Delete failed: $e");
    }
  }

  // 17. Create Personal Radar
  Future<void> createPersonalRadar({
    required String targetUserId,
    required String churchId,
    required String churchName,
    required DateTime scheduleTime,
    required String message,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    try {
      final radar = await _supabase.from('radars').insert({
        'user_id': currentUser.id,
        'target_user_id': targetUserId,
        'type': 'personal',
        'visibility': 'private',
        'status': 'pending',
        'title': 'Ajakan Misa Bersama',
        'description': message,
        'church_id': churchId,
        'location_name': churchName,
        'schedule_time': scheduleTime.toIso8601String(),
        'participants': [currentUser.id, targetUserId],
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'actor_id': currentUser.id,
        'type': 'invite_misa',
        'title': 'Ajakan Misa',
        'body': 'mengajak Anda Misa di $churchName',
        'related_id': radar['id'],
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      throw Exception("Gagal mengirim undangan radar: $e");
    }
  }

  // 18. Accept Personal Radar
  Future<void> acceptPersonalRadar(String radarId, String senderId) async {
    try {
      final chatId = await startChat(senderId);
      await _supabase.from('radars').update({
        'status': 'active',
        'chat_group_id': chatId 
      }).eq('id', radarId);

    } catch (e) {
      throw Exception("Gagal menerima undangan: $e");
    }
  }

  // 19. Fetch My Radars
  Future<List<Map<String, dynamic>>> fetchMyRadars() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('radars')
          .select('*, churches(name), profiles:user_id(full_name, avatar_url)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // 20. Fetch Radar Invites
  Future<List<Map<String, dynamic>>> fetchRadarInvites() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('radars')
          .select('*, churches(name), profiles:user_id(full_name, avatar_url)')
          .eq('type', 'personal')
          .eq('target_user_id', user.id)
          .neq('status', 'active') 
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // 21. Fetch Public Radars
  Future<List<Map<String, dynamic>>> fetchPublicRadars() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final List<Future<dynamic>> tasks = [
        _supabase.from('profiles').select('diocese_id').eq('id', user.id).single(),
        _supabase.from('follows').select('following_id').eq('follower_id', user.id),
      ];

      final results = await Future.wait(tasks);

      final myDioceseId = (results[0] as Map)['diocese_id'];
      final followingList = (results[1] as List).map((e) => e['following_id']).toSet();

      final response = await _supabase
          .from('radars')
          .select('*, churches(name), profiles:user_id(full_name, avatar_url, diocese_id)')
          .eq('visibility', 'public')
          .neq('user_id', user.id)
          .order('created_at', ascending: false);

      final allRadars = List<Map<String, dynamic>>.from(response);

      final filtered = allRadars.where((radar) {
        final ownerData = radar['profiles'];
        if (ownerData == null) return false;

        final ownerId = radar['user_id'];
        final ownerDiocese = ownerData['diocese_id'];

        final isFriend = followingList.contains(ownerId);
        final isSameDiocese = (myDioceseId != null && ownerDiocese == myDioceseId);

        return isFriend || isSameDiocese;
      }).toList();

      return filtered;

    } catch (e) {
      return [];
    }
  }
}
