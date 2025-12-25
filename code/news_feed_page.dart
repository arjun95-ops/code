import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/core/theme.dart';

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({super.key});

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  final _supabase = Supabase.instance.client;
  String _filterValue = "Global / All";
  String _userName = "Teman";

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      // Try to get name from metadata or profiles table
      try {
        final data = await _supabase.from('profiles').select('full_name').eq('id', user.id).single();
        if (mounted && data['full_name'] != null) {
          setState(() {
            _userName = data['full_name'].toString().split(' ').first; // First name only
          });
        }
      } catch (_) {}
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return "Selamat Pagi";
    if (hour < 15) return "Selamat Siang";
    if (hour < 18) return "Selamat Sore";
    return "Selamat Malam";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light gray background for contrast
      body: CustomScrollView(
        slivers: [
          // 1. CUSTOM HEADER (Blue Gradient + Overlap)
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // A. THE BLUE HEADER
                Container(
                  height: 240,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: kSignatureGradient, // Blue Gradient from Theme
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$_greeting, $_userName",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Semoga harimu penuh berkah.",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              // Notification Bell
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed: () {}, 
                                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Daily Verse Placeholder (Simple)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Bacaan Hari Ini: Mat 5:1-12",
                                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14)
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),

                // B. THE OVERLAPPING SEARCH / INPUT
                Positioned(
                  bottom: -30, 
                  left: 20, 
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0088CC).withOpacity(0.15), // Blue Shadow
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[100],
                          child: const Icon(Icons.edit, color: kPrimary, size: 18),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "Apa cerita imanmu hari ini?",
                            style: GoogleFonts.outfit(color: kTextMeta, fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.image_outlined, color: kTextMeta),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Spacer for overlapping container
          const SliverToBoxAdapter(child: SizedBox(height: 50)),

          // 2. FILTER & CONTENT
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                 // Filter
                 Row(
                   children: [
                     const Icon(Icons.tune_rounded, size: 18, color: kTextTitle),
                     const SizedBox(width: 8),
                     Text("Terbaru", style: GoogleFonts.outfit(color: kTextTitle, fontWeight: FontWeight.bold)),
                     const Spacer(),
                     _buildFilterChip(),
                   ],
                 ),
                 const SizedBox(height: 16),
              ]),
            ),
          ),

          // 3. POSTS LIST
          SliverPadding(
             padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
             sliver: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Stream.value([]), // TODO: Connect to 'posts' table
                builder: (context, snapshot) {
                  // MOCK DATA FOR UI VISUALIZATION
                  final isEmpty = true; // Force empty for now based on previous context

                  if (isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.only(top: 40),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade100)
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.1),
                                shape: BoxShape.circle
                              ),
                              child: const Icon(Icons.volunteer_activism_rounded, size: 40, color: kPrimary),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Belum ada cerita", 
                              style: GoogleFonts.outfit(color: kTextTitle, fontWeight: FontWeight.bold, fontSize: 18)
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Jadilah yang pertama membagikan momen iman Anda di sini!",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(color: kTextBody, height: 1.5),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {}, 
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
                              ),
                              child: const Text("Buat Postingan")
                            )
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // If data exists...
                  return SliverList(delegate: SliverChildBuilderDelegate((ctx, idx) => const SizedBox(), childCount: 0));
                },
             ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Text("Global", style: GoogleFonts.outfit(color: kTextBody, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: kTextMeta)
        ],
      ),
    );
  }
}
