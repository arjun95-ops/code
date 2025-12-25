import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/services/supabase_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/post_detail_screen.dart';
import 'package:mychatolic_app/pages/other_user_profile_page.dart';
import 'package:mychatolic_app/pages/edit_post_page.dart';

class PostCard extends StatefulWidget {
  final UserPost post;
  final SupabaseService supabaseService; 
  final VoidCallback? onTap; // Null means default navigation behavior
  final Function(UserPost)? onPostUpdated;
  final String? heroTagPrefix;

  const PostCard({
    super.key, 
    required this.post, 
    required this.supabaseService,
    this.onTap,
    this.onPostUpdated,
    this.heroTagPrefix,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  int likesCount = 0;
  int commentsCount = 0;
  StreamSubscription<UserPost>? _postSubscription;

  @override
  void initState() {
    super.initState();
    // 1. Initial State from Widget
    likesCount = widget.post.likesCount;
    isLiked = widget.post.isLikedByMe;
    commentsCount = widget.post.commentsCount;
    
    // 2. Subscribe to Global Broadcast Stream
    _postSubscription = SupabaseService.postUpdateStream.listen((updatedPost) {
      if (!mounted) return;
      
      // If this event matches OUR post ID, update local state
      if (updatedPost.id == widget.post.id) {
         setState(() {
           likesCount = updatedPost.likesCount;
           isLiked = updatedPost.isLikedByMe;
           commentsCount = updatedPost.commentsCount;
           // IMPORTANT: We do NOT update author/image here to prevent flickering or data loss 
           // if the broadcast payload is incomplete.
         });
      }
    });
  }
  
  @override
  void dispose() {
    _postSubscription?.cancel();
    super.dispose();
  }

  void _handleMainTap() async {
    if (widget.onTap != null) {
      widget.onTap!(); 
    } else {
      // 1. Construct updated post from LOCAL state
      final localPost = widget.post.copyWith(
        likesCount: likesCount,
        isLikedByMe: isLiked,
        commentsCount: commentsCount
      );

      // 2. Navigate and wait for result
      final result = await Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: localPost))
      );
      
      // 3. Sync Back BROADCAST on Return (if Detail screen returned data)
      if (result is UserPost && mounted) {
           // Broadcast to ensure all views (Feed, Profile, etc.) are in sync with what happened in Detail
           SupabaseService.broadcastPostUpdate(result);
      }
    }
  }

  void _handleLike() async {
    final newLiked = !isLiked;
    final newCount = likesCount + (newLiked ? 1 : -1);

    // 1. Optimistic Update Local State
    setState(() {
      isLiked = newLiked;
      likesCount = newCount;
    });
    
    // 2. Create Updated Object
    final updatedPost = widget.post.copyWith(
       isLikedByMe: newLiked,
       likesCount: newCount,
       commentsCount: commentsCount
    );

    // 3. BROADCAST IMMEDIATELY (Instantly updates other screens)
    SupabaseService.broadcastPostUpdate(updatedPost);
    
    // 4. Notify Parent (Callback) - Legacy/Direct parent usage
    widget.onPostUpdated?.call(updatedPost);
    
    // 5. Server Request
    try {
      await widget.supabaseService.toggleLike(widget.post.id);
    } catch (e) {
      if (mounted) {
        // Revert on Failure
        final revertedLocked = !isLiked;
        final revertedCount = likesCount + (revertedLocked ? 1 : -1);
        
        setState(() {
           isLiked = revertedLocked;
           likesCount = revertedCount;
        });
        
        // Revert Broadcast
        SupabaseService.broadcastPostUpdate(widget.post.copyWith(
           isLikedByMe: revertedLocked,
           likesCount: revertedCount,
           commentsCount: commentsCount
        ));
      }
    }
  }

  void _handleShare() {
    final String caption = widget.post.caption ?? "Postingan dari MyCatholic";
    final String image = widget.post.imageUrl ?? "";
    final String content = "$caption\n\n$image".trim();

    if (content.isNotEmpty) {
      Share.share(content);
    } else {
      Share.share("Cek postingan menarik ini di MyCatholic!");
    }
  }

  void _showPostOptions(BuildContext context) {
    final currentUser = widget.supabaseService.currentUser;
    final bool isMyPost = currentUser != null && widget.post.author?.id == currentUser.id;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isMyPost) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Edit Post'),
                  onTap: () async {
                    Navigator.pop(context);
                    // Edit Flow
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditPostPage(post: widget.post)),
                    );
                    
                    if (result is UserPost && context.mounted) {
                       SupabaseService.broadcastPostUpdate(result); // Broadcast Edit
                       widget.onPostUpdated?.call(result); 
                       
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text("Postingan berhasil diperbarui"))
                       );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Post'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context);
                  },
                ),
              ] else ...[
                ListTile(
                    leading: const Icon(Icons.flag_outlined, color: Colors.red),
                    title: const Text('Report Post'),
                    onTap: () {
                      Navigator.pop(context); 
                      _showReportReasonDialog(context);
                    },
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hapus Postingan?"),
          content: const Text("Apakah Anda yakin ingin menghapus postingan ini? Tindakan ini tidak dapat dibatalkan."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePost();
              },
              child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost() async {
    try {
      await widget.supabaseService.deletePost(widget.post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Postingan berhasil dihapus"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus: $e"))
        );
      }
    }
  }

  void _showReportReasonDialog(BuildContext context) {
    final reasons = [
      "Inappropriate Content",
      "Spam",
      "Hate Speech",
      "Harassment",
      "False Information",
      "Other"
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Report Reason"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons.map((r) => ListTile(
                title: Text(r),
                onTap: () {
                  Navigator.pop(context); // Close dialog
                  _submitReport(r);
                },
              )).toList(),
            ),
          ),
          actions: [
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: const Text("Cancel"),
             )
          ],
        );
      },
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      await widget.supabaseService.reportPost(widget.post.id, reason);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Laporan berhasil dikirim. Terima kasih."))
         );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Gagal mengirim laporan: $e"))
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post.author;
    String timeAgo = "Baru saja";
    try {
       timeAgo = timeago.format(widget.post.createdAt);
    } catch (e) {
       timeAgo = "-";
    }

    final displayContent = widget.post.caption ?? widget.post.content;

    return GestureDetector(
      onTap: _handleMainTap,
      child: Container(
        color: Colors.white, 
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () {
                  if (author != null) {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => OtherUserProfilePage(userId: author.id)
                      )
                    );
                  }
                },
                child: Row(
                  children: [
                     Container(
                       width: 40, height: 40,
                       decoration: const BoxDecoration(shape: BoxShape.circle),
                       child: SafeNetworkImage(
                         imageUrl: author?.avatarUrl, // CORRECTED TO USE AVATAR URL
                         width: 40, height: 40,
                         borderRadius: BorderRadius.circular(20),
                         fit: BoxFit.cover,
                         fallbackIcon: Icons.person,
                         iconColor: Colors.grey,
                         fallbackColor: Colors.grey[200],
                       ),
                     ),
                     const SizedBox(width: 10),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(author?.fullName ?? "User", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextTitle)),
                           Text("${author?.role ?? '-'} • $timeAgo", style: GoogleFonts.outfit(fontSize: 12, color: kTextMeta)),
                         ],
                       ),
                     ),
                     GestureDetector(
                       onTap: () => _showPostOptions(context),
                       child: const Icon(Icons.more_horiz, color: kTextMeta),
                     ),
                   ],
                ),
              ),
            ),
             
             const SizedBox(height: 12),
             
             // Content Text
             if (displayContent != null && displayContent.isNotEmpty)
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 child: Text(
                    displayContent,
                    style: GoogleFonts.outfit(color: kTextBody, fontSize: 16, height: 1.5),
                 ),
               ),
             
             const SizedBox(height: 12),
 
             // Image with Hero
             if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty)
                GestureDetector(
                  onTap: _handleMainTap, 
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Hero(
                       tag: "${widget.heroTagPrefix ?? 'post'}_${widget.post.id}",
                       child: AspectRatio(
                         aspectRatio: 4 / 5,
                         child: SafeNetworkImage(
                           imageUrl: widget.post.imageUrl!,
                           fit: BoxFit.cover,
                           borderRadius: BorderRadius.circular(16),
                           fallbackIcon: Icons.image_not_supported,
                           fallbackColor: Colors.grey[100],
                         ),
                       ),
                    ),
                  ),
                ),

            const SizedBox(height: 12),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Like (Independent Action)
                  GestureDetector(
                    onTap: _handleLike,
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                          color: isLiked ? Colors.deepOrange : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 6),
                        Text("$likesCount", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextMeta)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  
                  // Comment (Triggers Navigation)
                  GestureDetector(
                    onTap: _handleMainTap, 
                    child: Row(
                      children: [
                         const Icon(Icons.chat_bubble_outline_rounded, color: kTextMeta, size: 22),
                         const SizedBox(width: 6),
                         Text("$commentsCount", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextMeta)),
                      ],
                    ),
                  ),
                  
                  const Spacer(),

                  // Share (Independent Action)
                  GestureDetector(
                    onTap: _handleShare, 
                    child: const Icon(Icons.share_outlined, color: kTextMeta, size: 22),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}