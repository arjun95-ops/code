import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/services/story_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/pages/story/create_story_page.dart';
import 'package:mychatolic_app/pages/story/story_view_page.dart';

import 'package:mychatolic_app/core/app_colors.dart'; 
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';
import 'package:mychatolic_app/features/social/search_user_page.dart'; 

class SocialInboxPage extends StatefulWidget {
  const SocialInboxPage({super.key});

  @override
  State<SocialInboxPage> createState() => _SocialInboxPageState();
}

class _SocialInboxPageState extends State<SocialInboxPage> {
  final _supabase = Supabase.instance.client;
  final StoryService _storyService = StoryService();

  List<UserStoryGroup> _activeStories = [];
  UserStoryGroup? _currentUserStory;
  bool _isLoadingStories = true;

  @override
  void initState() {
    super.initState();
    _fetchStories();
  }

  Future<void> _fetchStories() async {
    if (!mounted) return;
    
    // 1. Fetch all active stories grouped by user
    final allStories = await _storyService.fetchActiveStories();
    final myId = _supabase.auth.currentUser?.id;

    List<UserStoryGroup> friendsStories = [];
    UserStoryGroup? myStory;

    // 2. Separate "My Story" from "Friend Stories"
    for (var group in allStories) {
      if (group.userId == myId) {
        myStory = group;
      } else {
        friendsStories.add(group);
      }
    }

    if (mounted) {
      setState(() {
        _activeStories = friendsStories;
        _currentUserStory = myStory;
        _isLoadingStories = false;
      });
    }
  }

  /// Handles refreshing data after returning from pages
  void _onReturn() {
    _fetchStories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: MyCatholicAppBar(
        title: "Pesan",
        actions: [
          IconButton(
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchUserPage())); 
            }, 
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. STORY HEADER (Top Tray)
          _buildStoryHeader(),
          
          // No visual divider here as requested for cleaner look, 
          // or a very subtle one if absolutely needed, but user asked for "clean".
          // Adding a very subtle one just to separate sections without being intrusive.
          Container(height: 1, color: Colors.grey.shade100),

          // 2. CHAT BODY (List)
          Expanded(child: _buildChatList()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI: STORY HEADER
  // ---------------------------------------------------------------------------
  Widget _buildStoryHeader() {
    return Container(
      height: 130.0, // STRICT: 130.0
      width: double.infinity,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // STRICT: symmetric(horizontal: 16, vertical: 10)
        itemCount: 1 + _activeStories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildMyStoryItem();
          }
          final friendStory = _activeStories[index - 1];
          return _buildFriendStoryItem(friendStory);
        },
      ),
    );
  }

  Widget _buildMyStoryItem() {
    final user = _supabase.auth.currentUser;
    final hasStory = _currentUserStory != null && _currentUserStory!.stories.isNotEmpty;

    return FutureBuilder(
      future: hasStory ? null : _supabase.from('profiles').select('avatar_url').eq('id', user!.id).single(),
      builder: (context, snapshot) {
        String? avatarUrl;
        if (hasStory) {
          avatarUrl = _currentUserStory!.userAvatar;
        } else if (snapshot.hasData) {
          avatarUrl = (snapshot.data as Map)['avatar_url'];
        }

        return GestureDetector(
          onTap: () {
            if (hasStory) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewPage(
                stories: _currentUserStory!.stories,
                userProfile: {
                  'full_name': 'Saya', 
                  'avatar_url': avatarUrl
                },
              ))).then((_) => _onReturn());
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoryPage()))
                  .then((result) { if (result == true) _onReturn(); });
            }
          },
          onLongPress: () {
             // Hidden feature for power user: Add Story even if has active story
             Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoryPage()))
                  .then((result) { if (result == true) _onReturn(); });
          },
          child: Container(
            width: 80.0, // STRICT: 80.0
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar Area (STRICT: 70x70)
                SizedBox(
                  width: 70, height: 70,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: hasStory 
                              ? const LinearGradient(
                                  colors: [Colors.purple, Colors.orange],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle, 
                            color: Colors.white
                          ),
                          child: SafeNetworkImage(
                            imageUrl: avatarUrl,
                            width: 60, height: 60,
                            borderRadius: BorderRadius.circular(100),
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.person,
                          ),
                        ),
                      ),
            
                      // "+" Badge (Logic Refined: Only if NO story)
                      if (!hasStory)
                        Positioned(
                          bottom: 0, 
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent, // Vibrant Blue
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2.5)),
                            ),
                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 6), // STRICT: 6.0
                
                // Text Label (STRICT: 12.0)
                Text(
                  "Cerita Anda",
                  style: GoogleFonts.outfit(fontSize: 12.0, color: Colors.black87),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildFriendStoryItem(UserStoryGroup group) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewPage(
           stories: group.stories,
           userProfile: {
             'full_name': group.userName,
             'avatar_url': group.userAvatar,
           },
        ))).then((_) => _onReturn());
      },
      child: Container(
        width: 80.0, // STRICT: 80.0
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar Area (STRICT: 70x70)
            SizedBox(
              width: 70, height: 70,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.orange, Colors.greenAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, 
                    color: Colors.white
                  ),
                  child: SafeNetworkImage(
                    imageUrl: group.userAvatar,
                    width: 60, height: 60,
                    borderRadius: BorderRadius.circular(100),
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 6), // STRICT: 6.0
            
            // Text Label (STRICT: 12.0)
            Text(
              group.userName.split(' ').first, 
              style: GoogleFonts.outfit(fontSize: 12.0, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI: CHAT LIST
  // ---------------------------------------------------------------------------
  Widget _buildChatList() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      return const Center(child: Text("Silakan login kembali."));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('social_chats')
          .stream(primaryKey: ['id'])
          .order('updated_at', ascending: false)
          .map((list) {
            return list.where((chat) {
              final participants = List<dynamic>.from(chat['participants'] ?? []);
              final createdBy = chat['created_by'];
              return participants.contains(myId) || createdBy == myId;
            }).toList();
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final chats = snapshot.data ?? [];
        
        if (chats.isEmpty) {
          return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                 const SizedBox(height: 16),
                 Text("Belum ada percakapan", style: GoogleFonts.outfit(color: Colors.grey)),
               ],
             )
          );
        }

        // STRICT: ListView.builder (NO Dividers)
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return _buildChatItem(chat, myId);
          },
        );
      },
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, String myId) {
    // Logic to find opponent
    final participants = List<dynamic>.from(chat['participants'] ?? []);
    
    // Safety check: if participants list is invalid or empty
    if (participants.isEmpty) return const SizedBox.shrink();

    // Find the ID that is NOT me
    final opponentId = participants.firstWhere(
      (id) => id != myId, 
      orElse: () => null
    );

    if (opponentId == null) return const SizedBox.shrink();

    return FutureBuilder(
      future: _supabase.from('profiles').select().eq('id', opponentId).maybeSingle(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
           return const SizedBox(height: 70); 
        }

        final profile = snapshot.data as Map<String, dynamic>;
        final name = profile['full_name'] ?? "User";
        final avatarUrl = profile['avatar_url'];
        
        final lastMsg = chat['last_message'] ?? "Memulai percakapan";
        final updatedAt = chat['updated_at'];
        
        // STRICT: No Bottom Border
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: SafeNetworkImage(
            imageUrl: avatarUrl,
            width: 50, height: 50,
            borderRadius: BorderRadius.circular(25),
            fit: BoxFit.cover,
            fallbackIcon: Icons.person,
          ),
          title: Text(
            name, 
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            lastMsg,
            style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
             updatedAt != null ? timeago.format(DateTime.parse(updatedAt), locale: 'en_short') : "",
             style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(
              chatId: chat['id'],
              opponentProfile: {
                'id': opponentId,
                'full_name': name,
                'avatar_url': avatarUrl,
              },
            )));
          },
        );
      }
    );
  }
}
