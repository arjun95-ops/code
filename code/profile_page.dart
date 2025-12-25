import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/services/profile_service.dart';
import 'package:mychatolic_app/services/story_service.dart';
import 'package:mychatolic_app/services/chat_service.dart';
import 'package:mychatolic_app/services/supabase_service.dart'; // IMPORTANT
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/widgets/post_card.dart'; // IMPORTANT
import 'package:mychatolic_app/pages/post_detail_screen.dart'; // IMPORTANT
import 'package:mychatolic_app/pages/settings_page.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/pages/story/story_view_page.dart';
import 'package:mychatolic_app/edit_profile_page.dart';
import 'package:mychatolic_app/pages/radars/create_invite_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId; // If null, shows current user's profile
  final bool isBackButtonEnabled; // For navigation from other pages

  const ProfilePage({
    super.key, 
    this.userId,
    this.isBackButtonEnabled = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final StoryService _storyService = StoryService();
  final ChatService _chatService = ChatService();
  final SupabaseService _supabaseService = SupabaseService(); // Used for posts to get Likes correctly
  final _supabase = Supabase.instance.client;

  late TabController _tabController;
  
  // State Variables
  bool _isLoading = true;
  String? _error;
  
  Profile? _profile;
  Map<String, int> _stats = {'followers': 0, 'following': 0, 'posts': 0};
  bool _isFollowing = false;
  bool _isMe = false;
  
  // Post Lists
  List<UserPost> _photoPosts = [];
  List<UserPost> _textPosts = [];
  bool _isLoadingPosts = true;

  // Stories
  List<Story> _userStories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkIsMe();
    _loadProfileData();
  }

  void _checkIsMe() {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (widget.userId == null || widget.userId == currentUserId) {
      _isMe = true;
    } else {
      _isMe = false;
    }
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final targetUserId = widget.userId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) throw Exception("User ID not found");

      // 1. Fetch Profile & Stats
      final data = await _profileService.fetchUserProfile(targetUserId);

      // 2. Load Active Stories
      final stories = await _storyService.fetchUserStories(targetUserId);

      // 3. Check Follow Status (if not me)
      if (!_isMe) {
        _isFollowing = await _profileService.checkIsFollowing(targetUserId);
      }

      if (mounted) {
        setState(() {
          _profile = data['profile'] as Profile;
          _stats = data['stats'] as Map<String, int>;
          _userStories = stories;
          _isLoading = false;
        });
      }

      // 4. Fetch Posts (Using SupabaseService to get correct Like interactions)
      _loadPosts(targetUserId);

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPosts(String userId) async {
    setState(() => _isLoadingPosts = true);
    
    // 1. Fetch via SupabaseService (This includes 'is_liked_by_me' logic!)
    List<UserPost> allPosts = await _supabaseService.fetchPosts(userId: userId);

    // 2. Filter Logic "Sapu Jagat"
    final List<UserPost> photos = [];
    final List<UserPost> texts = [];

    for (var p in allPosts) {
      // Logic: Jika type='photo' ATAU punya URL gambar, masuk grid foto.
      bool isPhoto = p.type == 'photo' || (p.imageUrl != null && p.imageUrl!.isNotEmpty);
      
      if (isPhoto) {
        photos.add(p);
      } else {
        texts.add(p);
      }
    }

    if (mounted) {
      setState(() {
        _photoPosts = photos;
        _textPosts = texts;
        _isLoadingPosts = false;
        
        // Update stats posts count locally just in case
        _stats['posts'] = allPosts.length;
      });
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_profile == null) return;
    
    final bool previousState = _isFollowing;
    final int previousCount = _stats['followers'] ?? 0;

    setState(() {
      if (previousState) {
        _isFollowing = false;
        _stats['followers'] = (previousCount > 0) ? previousCount - 1 : 0;
      } else {
        _isFollowing = true;
        _stats['followers'] = previousCount + 1;
      }
    });

    try {
      if (previousState) {
        await _profileService.unfollowUser(_profile!.id);
      } else {
        await _profileService.followUser(_profile!.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = previousState;
          _stats['followers'] = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    }
  }

  Future<void> _navigateToChat() async {
     if (_profile != null) {
        try {
          final chatId = await _chatService.getOrCreatePrivateChat(_profile!.id);
          
          if (!mounted) return;

          final Map<String, dynamic> opponentProfileMap = {
            'id': _profile!.id,
            'full_name': _profile!.fullName ?? "User",
            'avatar_url': _profile!.avatarUrl,
            'role': _profile!.role,
          };

          Navigator.push(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(
            chatId: chatId, 
            opponentProfile: opponentProfileMap,
          )));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        }
     }
  }
  
  Future<void> _handleEditProfile() async {
    // Await navigation result
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    
    // Check if result is true (Profile Updated)
    if (result == true) {
      _loadProfileData(); 
    }
  }

  Future<void> _openSettings() async {
    // Tunggu sampai user kembali dari halaman Settings
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const SettingsPage())
    );
    
    // Setelah kembali, REFRESH data profil segera
    if (mounted) {
      _loadProfileData(); 
    }
  }

  void _handleAvatarTap() {
    if (_userStories.isNotEmpty) {
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => StoryViewPage(
          stories: _userStories, 
          userProfile: {
             'full_name': _profile?.fullName,
             'avatar_url': _profile?.avatarUrl,
          },
        )),
      ).then((_) {
         _loadProfileData(); 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0088CC);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text(_error ?? "Unknown Error")),
      );
    }

    if (_profile == null) return const Scaffold(body: Center(child: Text("User not found")));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              backgroundColor: primaryBlue,
              elevation: 0,
              leading: widget.isBackButtonEnabled ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ) : null,
              title: Text(
                _profile!.fullName ?? "Profile", 
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              centerTitle: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              actions: [
                if (_isMe)
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: _openSettings,
                  )
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (val) {
                       if (val == 'report') {
                         _showReportDialog(context);
                       }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'report', child: Text("Report User")),
                    ],
                  )
              ],
            ),

            SliverToBoxAdapter(
              child: ProfileHeader(
                profile: _profile!,
                stats: _stats,
                isMe: _isMe,
                isFollowing: _isFollowing,
                onFollowToggle: _handleFollowToggle,
                onChatTap: _navigateToChat,
                onEditTap: _handleEditProfile,
                hasStories: _userStories.isNotEmpty,
                onAvatarTap: _handleAvatarTap,
              ),
            ),
            
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: primaryBlue,
                  labelColor: primaryBlue,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded)),
                    Tab(icon: Icon(Icons.list_rounded)),
                  ],
                )
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGridPosts(),
            _buildListPosts(),
          ],
        ),
      ),
    );
  }

  Widget _buildGridPosts() {
     if (_isLoadingPosts) return const Center(child: CircularProgressIndicator());
     
     if (_photoPosts.isEmpty) {
       return _buildEmptyState("Belum ada foto");
     }

     return GridView.builder(
       padding: const EdgeInsets.all(2),
       // Physics is handled by NestedScrollView if we don't set it to NeverScrollable, 
       // but typically for TabBarView inside NestedScrollView we use CustomScrollView with SliverFillRemaining.
       // Here standard GridView inside TabBarView works if we supply no physics or appropriate physics?
       // Actually 'NeverScrollable' is problematic if the content is longer than screen BUT we are inside NestedScrollView body.
       // The documented way is using CustomScrollView with SliverFixedExtentListKey or key.
       // However, strictly adhering to 'rewrite' request:
       // Using 'Builder' context with 'PrimaryScrollController' often works.
       // Let's use standard builder but verify later. 
       // User asked for "Simple" rewrite.
       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
         crossAxisCount: 3, 
         childAspectRatio: 1, // Instagram square
         crossAxisSpacing: 2, 
         mainAxisSpacing: 2
       ),
       itemCount: _photoPosts.length,
       itemBuilder: (context, index) {
         final post = _photoPosts[index];
         return GestureDetector(
           onTap: () {
             Navigator.push(
               context,
               MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))
             );
           },
           child: SafeNetworkImage(
             imageUrl: post.imageUrl ?? "",
             fit: BoxFit.cover,
           ),
         );
       },
     );
  }

  Widget _buildListPosts() {
    if (_isLoadingPosts) return const Center(child: CircularProgressIndicator());

    if (_textPosts.isEmpty) {
       return _buildEmptyState("Belum ada postingan teks");
     }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
      itemCount: _textPosts.length,
      separatorBuilder: (_, __) => Container(height: 8, color: Colors.grey[100]),
      itemBuilder: (context, index) {
        final post = _textPosts[index];
        // USE POST CARD FOR INTERACTIONS
        return PostCard(
          post: post, 
          supabaseService: _supabaseService,
          onPostUpdated: (updatedPost) {
            setState(() {
              _textPosts[index] = updatedPost;
            });
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_none, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(msg, style: GoogleFonts.outfit(color: Colors.grey)),
        ],
      ),
    );
  }
  Future<void> _showReportDialog(BuildContext context) async {
    String selectedReason = 'Konten tidak pantas';
    final TextEditingController descController = TextEditingController();
    
    final List<String> reasons = [
      'Konten tidak pantas',
      'Pelecehan',
      'Akun palsu',
      'Penipuan',
      'Lainnya',
    ];

    return showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Laporkan User", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text("Alasan:", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                   DropdownButton<String>(
                     value: selectedReason,
                     isExpanded: true,
                     items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), 
                     onChanged: (val) {
                       if (val != null) setStateDialog(() => selectedReason = val);
                     },
                   ),
                   const SizedBox(height: 12),
                   Text("Keterangan Tambahan:", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   TextField(
                     controller: descController,
                     decoration: const InputDecoration(
                       hintText: "Jelaskan detail laporan...",
                       border: OutlineInputBorder(),
                       isDense: true,
                     ),
                     maxLines: 3,
                   )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text("Batal")
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    Navigator.pop(ctx); // Close Dialog
                    
                    // Show Loading
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mengirim laporan...")));
                    
                    try {
                      await _profileService.reportUser(
                        _profile!.id, 
                        selectedReason, 
                        descController.text.trim()
                      );
                      
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan diterima dan akan ditinjau Admin")));
                      }
                    } catch (e) {
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal lapor: $e")));
                      }
                    }
                  }, 
                  child: const Text("Kirim Laporan", style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// HELPER CLASSES
// ---------------------------------------------------------------------------

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white, // Background for pinned tab bar
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class ProfileHeader extends StatelessWidget {
  final Profile profile;
  final Map<String, int> stats;
  final bool isMe;
  final bool isFollowing;
  final VoidCallback onFollowToggle;
  final VoidCallback onChatTap;
  final VoidCallback? onEditTap;
  final bool hasStories;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.stats,
    required this.isMe,
    required this.isFollowing,
    required this.onFollowToggle,
    required this.onChatTap,
    this.onEditTap,
    this.hasStories = false,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          // 1. Avatar & Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                 onTap: onAvatarTap,
                 child: Container(
                   padding: const EdgeInsets.all(3),
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     gradient: hasStories 
                        ? const LinearGradient(
                            colors: [Colors.purple, Colors.orange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null, 
                   ),
                   child: Container(
                     padding: const EdgeInsets.all(2),
                     decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).scaffoldBackgroundColor,
                     ),
                     child: _buildAvatar(),
                   ),
                 ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(stats['posts'].toString(), "Posts"),
                      _buildStat(stats['followers'].toString(), "Followers"),
                      _buildStat(stats['following'].toString(), "Following"),
                    ],
                  ),
                ),
              )
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 2. Name & Bio
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      (profile.fullName == null || profile.fullName!.isEmpty) 
                          ? "Umat MyCatholic" 
                          : profile.fullName!,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    _buildVerificationBadge(),
                  ],
                ),
                
                if (profile.role != null && !['umat', 'katekumen'].contains(profile.role!.toLowerCase()))
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      profile.role!.toUpperCase(),
                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),

                const SizedBox(height: 8),

                if (profile.bio != null && profile.bio!.isNotEmpty)
                  Text(
                    profile.bio!, 
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                  )
                else 
                   Text(
                    "Umat Katolik yang aktif.", 
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),

                 Padding(
                   padding: const EdgeInsets.only(top: 8),
                   child: Row(
                     children: [
                       const Icon(Icons.location_on, size: 13, color: Colors.grey),
                       const SizedBox(width: 4),
                       Expanded(
                         child: Text(
                           "📍 ${profile.parish ?? '-'}, ${profile.diocese ?? '-'}, ${profile.country ?? 'Indonesia'}",
                           style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]), 
                           maxLines: 2, overflow: TextOverflow.ellipsis,
                         ),
                       ),
                     ],
                   ),
                 ),

                if (profile.showAge || profile.showEthnicity)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 20),
                    child: Text(
                      "${profile.showAge ? 'Usia: ${profile.age ?? '-'} thn' : ''}${profile.showAge && profile.showEthnicity ? ' • ' : ''}${profile.showEthnicity ? 'Suku: ${profile.ethnicity ?? '-'}' : ''}",
                       style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 3. Buttons
          SizedBox(
            height: 40,
            child: Row(
              children: [
                if (isMe)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onEditTap,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Edit Profile", style: GoogleFonts.outfit(color: Colors.black)),
                    ),
                  )
                else ...[
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: onFollowToggle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.grey[200] : const Color(0xFF0088CC),
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        isFollowing ? "Unfollow" : "Follow", 
                        style: GoogleFonts.outfit(color: isFollowing ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: onChatTap,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Message", style: GoogleFonts.outfit(color: Colors.black)),
                    ),
                  ),
                  
                  if (_shouldShowMassInvite(profile.role)) ...[
                    const SizedBox(width: 8),
                    Expanded(
                       flex: 2,
                       child: OutlinedButton.icon(
                         onPressed: () {
                           showModalBottomSheet(
                             context: context,
                             isScrollControlled: true,
                             shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                             builder: (context) => CreateInvitePage(
                               targetUserId: profile.id,
                               targetUserName: profile.fullName ?? "Teman",
                             ),
                           );
                         },
                         style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: Colors.orange.withOpacity(0.05),
                         ),
                         icon: const Icon(Icons.church, size: 16, color: Colors.orange),
                         label: Text("Misa", style: GoogleFonts.outfit(color: Colors.orange, fontSize: 12)),
                       ),
                     ),
                  ]
                ]
              ],
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge() {
    final role = profile.role?.toLowerCase() ?? 'umat';
    final status = profile.verificationStatus?.toLowerCase() ?? 'unverified';
    final isApproved = status == 'approved';

    // Special Roles
    if (['pastor', 'suster', 'bruder', 'katekis', 'imam'].contains(role)) {
       Color badgeColor = const Color(0xFF0F0C29);
       Color textColor = Colors.white;
       IconData icon = Icons.verified_user;
       String label = role.characters.first.toUpperCase() + role.substring(1); 
       
       if (role == 'pastor' || role == 'imam') {
         badgeColor = const Color(0xFF003366);
         icon = Icons.health_and_safety_rounded;
       } else if (role == 'suster') {
         badgeColor = const Color(0xFF5D4037);
         icon = Icons.volunteer_activism;
       } 

       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
         decoration: BoxDecoration(
           color: badgeColor,
           borderRadius: BorderRadius.circular(4),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             if (isApproved) ...[
                Icon(icon, color: Colors.amber, size: 12),
                const SizedBox(width: 4),
             ],
             Text(
               isApproved ? "$label (Valid)" : "$label (Pending)", 
               style: GoogleFonts.outfit(fontSize: 10, color: textColor, fontWeight: FontWeight.bold)
             ),
           ],
         ),
       );
    }
    
    // Umat
    if (isApproved) {
       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         decoration: BoxDecoration(
           color: Colors.green.withOpacity(0.1),
           borderRadius: BorderRadius.circular(4),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.verified, color: Colors.green, size: 14),
             const SizedBox(width: 4),
             Text("100% Katolik", style: GoogleFonts.outfit(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
           ],
         ),
       );
    }
    
    if (status == 'pending') {
       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         decoration: BoxDecoration(
           color: const Color(0xFF0088CC).withOpacity(0.1),
           borderRadius: BorderRadius.circular(4),
         ),
         child: const Text("Menunggu Verifikasi", style: TextStyle(fontSize: 10, color: Color(0xFF0088CC), fontWeight: FontWeight.bold)),
       );
    }

    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
       decoration: BoxDecoration(
         color: Colors.grey.withOpacity(0.1),
         borderRadius: BorderRadius.circular(4),
       ),
       child: Text("Unverified", style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  bool _shouldShowMassInvite(String? role) {
    if (role == null) return true;
    final r = role.toLowerCase();
    return r == 'umat' || r == 'katekumen'; 
  }

  Widget _buildAvatar() {
     if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
        return CircleAvatar(
          radius: 40,
          backgroundColor: const Color(0xFFEEEEEE),
          child: const Icon(Icons.person, color: Colors.grey, size: 40),
        );
     }
     return ClipRRect(
       borderRadius: BorderRadius.circular(40),
       child: SafeNetworkImage(
         imageUrl: profile.avatarUrl!,
         width: 80, height: 80,
         fit: BoxFit.cover,
       ),
     );
  }
}
