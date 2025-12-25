import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/pages/notification_screen.dart';
import 'package:mychatolic_app/pages/post_detail_screen.dart';
import 'package:mychatolic_app/services/supabase_service.dart';
import 'package:mychatolic_app/widgets/post_card.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  // Filter State
  String _filterLabel = "Semua"; 
  String? _filterType; 
  dynamic _filterId; 

  // Pagination State
  List<UserPost> _posts = [];
  bool _isLoading = true;
  bool _isLoadMoreRunning = false;
  bool _hasNextPage = true;
  int _currentPage = 0;
  final int _limit = 20;
  String? _error;
  
  @override
  bool get wantKeepAlive => true; // Prevent rebuild/refetch on tab switch or back

  @override
  void initState() {
    super.initState();
    refreshPosts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && 
        !_isLoading && 
        !_isLoadMoreRunning && 
        _hasNextPage) {
      _loadMorePosts();
    }
  }

  // Initial Load / Refresh
  Future<void> refreshPosts() async {
    // Only clear list if it's a manual refresh (pull-to-refresh or filter change), 
    // NOT on initial load if we already have data (though initState handles logic).
    // Here we can simply set loading state.
    
    if(mounted) setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _hasNextPage = true;
      // Do NOT clear _posts immediately to avoid empty screen flash if simply refreshing
      // But for pagination consistency on refresh, we usually valid.
    });
    
    try {
      final posts = await _supabaseService.fetchPosts(
        filterType: _filterType,
        filterId: _filterId?.toString(),
        page: _currentPage,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          if (posts.length < _limit) {
            _hasNextPage = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Load More (Pagination)
  Future<void> _loadMorePosts() async {
    if (_isLoadMoreRunning || !_hasNextPage) return;

    setState(() {
      _isLoadMoreRunning = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final posts = await _supabaseService.fetchPosts(
        filterType: _filterType,
        filterId: _filterId?.toString(),
        page: nextPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          if (posts.isNotEmpty) {
            _posts.addAll(posts);
            _currentPage = nextPage;
          }
          if (posts.length < _limit) {
            _hasNextPage = false;
          }
          _isLoadMoreRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadMoreRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat lebih banyak: $e')));
      }
    }
  }

  // --- SMART FILTER LOGIC ---
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSearchSheet(
        onSelect: (label, type, id) {
           setState(() {
             _filterLabel = label;
             _filterType = type;
             _filterId = id;
           });
           Navigator.pop(context);
           refreshPosts();
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // REQUIRED for KeepAlive
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.dividerColor;
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: MyCatholicAppBar(
        title: "MyCatholic",
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())), 
            icon: const Icon(Icons.local_fire_department_rounded, color: Colors.white)
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. SMART FILTER DROPDOWN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: GestureDetector(
              onTap: _showFilterModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? theme.inputDecorationTheme.fillColor : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Filter Lokasi", style: GoogleFonts.outfit(fontSize: 10, color: metaColor)),
                          Text(_filterLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: titleColor, fontSize: 14), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: metaColor),
                  ],
                ),
              ),
            ),
          ),
          
          // 2. FEED
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : (_error != null)
                  ? Center(child: Text("Error: $_error", style: GoogleFonts.outfit(color: Colors.red)))
                  : (_posts.isEmpty)
                      ? Center(child: Text("Belum ada postingan.", style: GoogleFonts.outfit(color: metaColor)))
                      : RefreshIndicator(
                          onRefresh: refreshPosts,
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 80),
                            separatorBuilder: (ctx, idx) => Divider(height: 1, color: borderColor),
                            itemCount: _posts.length + (_isLoadMoreRunning ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _posts.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }

                              final post = _posts[index];
                              // Use the new reusable PostCard
                              return PostCard(
                                post: post, 
                                supabaseService: _supabaseService,
                                onTap: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
                                },
                                onPostUpdated: (updatedPost) {
                                  setState(() {
                                    _posts[index] = updatedPost;
                                  });
                                },
                                heroTagPrefix: 'home',
                              );
                            },
                          ),
                        ),
          ),
        ],
      ),
    );
  }
}

// --- SEARCH FILTER SHEET ---

class _FilterSearchSheet extends StatefulWidget {
  final Function(String label, String? type, dynamic id) onSelect;
  const _FilterSearchSheet({required this.onSelect});

  @override
  State<_FilterSearchSheet> createState() => _FilterSearchSheetState();
}

class _FilterSearchSheetState extends State<_FilterSearchSheet> {
  final _searchController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  // Quick Options State
  int? _myCountryId;
  int? _myDioceseId;
  String? _myChurchId;
  String? _myChurchName;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  void _fetchUserLocation() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('country_id, diocese_id, church_id, churches(name)') // Join to get church name
            .eq('id', user.id)
            .single();
            
        if (mounted) {
          setState(() {
            _myCountryId = data['country_id'];
            _myDioceseId = data['diocese_id'];
            _myChurchId = data['church_id'];
            // Access joined church name safely
            if (data['churches'] != null) {
               _myChurchName = data['churches']['name'];
            }
          });
        }
      } catch (e) {
        // silent
      }
    }
  }

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    
    setState(() => _isSearching = true);
    final results = await _supabaseService.searchLocations(query);
    if (mounted) {
      setState(() => _searchResults = results);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Use scaffold bg for consistent look
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          
          Text("Pilih Lokasi", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 16),
          
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: _onSearch,
            style: GoogleFonts.outfit(color: titleColor),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: metaColor),
              hintText: "Cari Negara, Keuskupan, atau Paroki...",
              hintStyle: GoogleFonts.outfit(color: metaColor),
              fillColor: isDark ? Colors.grey[800] : const Color(0xFFF3F4F6),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // List
          Expanded(
            child: _isSearching ? _buildSearchResults(titleColor, metaColor) : _buildQuickOptions(titleColor, metaColor, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOptions(Color titleColor, Color metaColor, ThemeData theme) {
    return ListView(
      children: [
        Text("OPSI CEPAT", style: GoogleFonts.outfit(color: metaColor, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        _buildOptionItem("Semua (Global)", null, null, Icons.public, titleColor, metaColor, theme),
        // Note: Casting IDs to String for consistency in logic as UUIDs are strings or large INTs handled as string in filter
        if (_myCountryId != null) _buildOptionItem("Negara Saya (Indonesia)", 'country', _myCountryId.toString(), Icons.flag, titleColor, metaColor, theme),
        if (_myDioceseId != null) _buildOptionItem("Keuskupan Saya", 'diocese', _myDioceseId.toString(), Icons.account_balance, titleColor, metaColor, theme), 
        if (_myChurchId != null) _buildOptionItem("Paroki Saya (${_myChurchName ?? 'Sendiri'})", 'church', _myChurchId.toString(), Icons.church, titleColor, metaColor, theme),
      ],
    );
  }

  Widget _buildSearchResults(Color titleColor, Color metaColor) {
    if (_searchResults.isEmpty) {
      return Center(child: Text("Tidak ditemukan.", style: GoogleFonts.outfit(color: metaColor)));
    }
    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (ctx, idx) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final theme = Theme.of(context);
        return _buildOptionItem(item['name'], item['type'], item['id'], Icons.place, titleColor, metaColor, theme);
      },
    );
  }

  Widget _buildOptionItem(String label, String? type, dynamic id, IconData icon, Color titleColor, Color metaColor, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isDark ? Colors.grey[800] : const Color(0xFFF3F4F6), shape: BoxShape.circle),
        child: Icon(icon, color: titleColor, size: 18),
      ),
      title: Text(label, style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.w600)),
      subtitle: type != null ? Text(type == 'country' ? 'Negara' : (type == 'diocese' ? 'Keuskupan' : 'Paroki'), style: GoogleFonts.outfit(fontSize: 12, color: metaColor)) : null,
      onTap: () {
        widget.onSelect(label, type, id);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    );
  }
}
