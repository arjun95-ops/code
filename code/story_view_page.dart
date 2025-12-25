import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/services/story_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryViewPage extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  
  // Optional: Pass in user profile directly if known, 
  // though stories usually contain author info if joined correctly.
  final Map<String, dynamic>? userProfile; 

  const StoryViewPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    this.userProfile,
  });

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnimation;

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  int _currentIndex = 0;
  final StoryService _storyService = StoryService();
  bool _isLiked = false;
  
  // Owner Check
  bool get _isOwner {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final story = widget.stories[_currentIndex];
    return myId == story.userId;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
    // Timer logic handled by AnimationController
    _animController = AnimationController(vsync: this);

    // Like Button Animation
    _likeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _likeScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _likeAnimController, curve: Curves.easeInOut),
    );

    // Pause on Type Logic
    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _animController.stop();
      } else {
        if (_animController.isAnimating || _animController.isCompleted) {
           // Do nothing if already stopped by other means
        } else {
           _animController.forward();
        }
      }
    });
    
    _loadStory(index: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _likeAnimController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _loadStory({required int index, bool animateToPage = false}) {
    // If index out of bounds (e.g. after deletion), close
    if (index >= widget.stories.length) {
      Navigator.pop(context);
      return;
    }

    _currentIndex = index;
    final story = widget.stories[index];
    
    // Reset Logic
    _animController.stop();
    _animController.reset();
    _animController.duration = const Duration(seconds: 5); 
    
    // If NOT owner, check like status. If owner, no need.
    if (!_isOwner) {
       _checkLikeStatus(story.id);
       _storyService.viewStory(story.id);
    }

    _animController.forward().whenComplete(() {
        _onStoryFinished();
    });

    if (animateToPage && _pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
    
    // Trigger rebuild to update UI (Owner vs Viewer)
    setState(() {});
  }

  Future<void> _checkLikeStatus(String storyId) async {
    // Optimistic reset first
    if (mounted) setState(() => _isLiked = false);
    
    final liked = await _storyService.hasLikedStory(storyId);
    if (mounted && widget.stories[_currentIndex].id == storyId) {
      setState(() => _isLiked = liked);
    }
  }

  void _onStoryFinished() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadStory(index: _currentIndex, animateToPage: true);
    } else {
      // End of stories
      Navigator.pop(context);
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_replyFocusNode.hasFocus) {
      _replyFocusNode.unfocus(); // Close keyboard on tap outside
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      // Prev
      if (_currentIndex > 0) {
        setState(() => _currentIndex--);
        _loadStory(index: _currentIndex, animateToPage: true);
      }
    } else {
      // Next
      _onStoryFinished();
    }
  }

  void _onLongPressStart() {
    if (!_replyFocusNode.hasFocus) {
        _animController.stop(); 
    }
  }

  void _onLongPressEnd() {
    if (!_replyFocusNode.hasFocus) {
        _animController.forward();
    }
  }

  // --- VIEWER ACTIONS ---

  void _handleLike() {
    final story = widget.stories[_currentIndex];
    
    // Optimistic Update
    setState(() {
      _isLiked = !_isLiked;
    });

    if (_isLiked) {
      _likeAnimController.forward().then((_) => _likeAnimController.reverse());
      _storyService.likeStory(story.id, story.userId, story.mediaUrl);
    } else {
      _storyService.unlikeStory(story.id);
    }
  }

  Future<void> _handleReply(String text) async {
    if (text.trim().isEmpty) return;
    
    final story = widget.stories[_currentIndex];
    
    _replyController.clear();
    _replyFocusNode.unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Mengirim balasan..."),
        duration: Duration(seconds: 1),
      )
    );
    
    _animController.forward();

    try {
       await _storyService.replyToStory(story.id, story.userId, text, story.mediaUrl);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Balasan terkirim!"))
         );
       }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal mengirim: $e"))
         );
       }
    }
  }

  // --- OWNER ACTIONS ---

  Future<void> _handleDelete() async {
    _animController.stop(); // Pause
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Story?"),
        content: const Text("Story ini akan dihapus permanen dan tidak bisa dikembalikan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Hapus", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );

    if (confirm == true) {
       final storyId = widget.stories[_currentIndex].id;
       
       try {
         await _storyService.deleteStory(storyId);
         
         if (!mounted) return;
         
         // Remove locally
         setState(() {
           widget.stories.removeAt(_currentIndex);
         });

         if (widget.stories.isEmpty) {
           Navigator.pop(context); // Close if no stories left
         } else {
           // Load next or previous
           if (_currentIndex >= widget.stories.length) {
             _currentIndex = widget.stories.length - 1;
           }
           _loadStory(index: _currentIndex, animateToPage: true);
         }
         
       } catch (e) {
         _animController.forward(); // Resume if fail
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal hapus: $e")));
       }
    } else {
      _animController.forward(); // Resume if cancel
    }
  }

  void _showViewers() {
    _animController.stop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
             return Column(
               children: [
                 const SizedBox(height: 12),
                 Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                 const SizedBox(height: 16),
                 Text("Dilihat oleh", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 10),
                 Expanded(
                   child: FutureBuilder<List<Map<String, dynamic>>>(
                     future: _storyService.fetchStoryViewers(widget.stories[_currentIndex].id),
                     builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final viewers = snapshot.data ?? [];
                        if (viewers.isEmpty) {
                          return Center(child: Text("Belum ada yang melihat", style: GoogleFonts.outfit(color: Colors.grey)));
                        }
                        
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: viewers.length,
                          itemBuilder: (context, index) {
                             final v = viewers[index];
                             return ListTile(
                               leading: SafeNetworkImage(
                                 imageUrl: v['avatar_url'],
                                 width: 40, height: 40,
                                 borderRadius: BorderRadius.circular(20),
                                 fit: BoxFit.cover,
                                 fallbackIcon: Icons.person,
                               ),
                               title: Text(v['full_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                               trailing: Text(
                                  timeago.format(DateTime.parse(v['viewed_at']), locale: 'en_short'),
                                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                               ),
                             );
                          },
                        );
                     },
                   ),
                 )
               ],
             );
          }
        );
      }
    ).whenComplete(() {
      _animController.forward(); // Resume when sheet closed
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
        Navigator.pop(context);
        return const SizedBox.shrink();
    }

    final story = widget.stories[_currentIndex];
    
    final name = story.authorName ?? widget.userProfile?['full_name'] ?? 'User';
    final avatar = story.authorAvatar ?? widget.userProfile?['avatar_url'];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: (_) => _onLongPressStart(),
        onLongPressEnd: (_) => _onLongPressEnd(),
        child: Stack(
          children: [
            // 1. STORY CAROUSEL
            Positioned.fill(
               child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Handle swipes manually
                itemCount: widget.stories.length,
                itemBuilder: (context, index) {
                  final s = widget.stories[index];
                  return _buildMediaView(s);
                },
              ),
            ),

            // 2. PROGRESS BARS
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              right: 10,
              child: Row(
                children: widget.stories.asMap().entries.map((entry) {
                   return Expanded(
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 2.0),
                       child: _buildProgressBar(entry.key),
                     ),
                   );
                }).toList(),
              ),
            ),

            // 3. HEADER (User Info & Close)
            Positioned(
              top: MediaQuery.of(context).padding.top + 25,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  SafeNetworkImage(
                    imageUrl: avatar,
                    width: 32, height: 32,
                    borderRadius: BorderRadius.circular(20),
                    fallbackIcon: Icons.person,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name, 
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(story.createdAt, locale: 'en_short'),
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            
            // 4. CAPTION
            if (story.caption != null && story.caption!.isNotEmpty)
               Positioned(
                 bottom: 100, 
                 left: 16,
                 right: 16,
                 child: Text(
                   story.caption!,
                   style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, shadows: [
                     const Shadow(color: Colors.black, blurRadius: 4),
                   ]),
                   textAlign: TextAlign.center,
                 ),
               ),
               
            // 5. BOTTOM INTERACTION OVERLAY (Conditional)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 1.0],
                  )
                ),
                child: SafeArea(
                  top: false,
                  child: _isOwner 
                      ? _buildOwnerControls() 
                      : _buildViewerControls(),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildViewerControls() {
    return Row(
      children: [
        // Reply Input
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.2),
               borderRadius: BorderRadius.circular(30),
               border: Border.all(color: Colors.white30, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _replyController,
              focusNode: _replyFocusNode,
              style: GoogleFonts.outfit(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: "Kirim pesan...",
                hintStyle: GoogleFonts.outfit(color: Colors.white70),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(bottom: 6),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _handleReply,
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Like Button
        ScaleTransition(
           scale: _likeScaleAnimation,
           child: IconButton(
             onPressed: _handleLike,
             icon: Icon(
               _isLiked ? Icons.local_fire_department : Icons.local_fire_department_outlined,
               color: _isLiked ? Colors.deepOrange : Colors.white,
               size: 28,
             ),
           ),
        ),
      ],
    );
  }

  Widget _buildOwnerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
         // Viewers Button (Left)
         GestureDetector(
           onTap: _showViewers,
           child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
             decoration: BoxDecoration(
               color: Colors.white24,
               borderRadius: BorderRadius.circular(20),
             ),
             child: Row(
               children: [
                 const Icon(Icons.remove_red_eye, color: Colors.white, size: 20),
                 const SizedBox(width: 6),
                 Text("Views", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
               ],
             ),
           ),
         ),

         // Delete Button (Right)
         IconButton(
           onPressed: _handleDelete,
           icon: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
         ),
      ],
    );
  }

  Widget _buildMediaView(Story story) {
    // For now, only Image. Expand for Video later.
    return Image.network(
       story.mediaUrl,
       fit: BoxFit.cover,
       loadingBuilder: (context, child, loadingProgress) {
         if (loadingProgress == null) return child;
         return const Center(child: CircularProgressIndicator(color: Colors.white));
       },
       errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white)),
    );
  }

  Widget _buildProgressBar(int index) {
      if (index < _currentIndex) {
        // Completed
        return Container(height: 2, color: Colors.white);
      } else if (index == _currentIndex) {
        // Current Animating
        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _animController.value,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.white30,
              minHeight: 2,
            );
          },
        );
      } else {
        // Future
        return Container(height: 2, color: Colors.white30);
      }
  }
}

