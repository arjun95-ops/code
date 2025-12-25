import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/app_colors.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/services/supabase_service.dart';
import 'package:mychatolic_app/pages/other_user_profile_page.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';

class SearchUserPage extends StatefulWidget {
  const SearchUserPage({super.key});

  @override
  State<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  final _supabase = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  // Data
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  // Filters (Raw Maps to handle UUIDs correctly)
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _dioceses = [];
  List<Map<String, dynamic>> _churches = [];

  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;

  @override
  void initState() {
    super.initState();
    _fetchFilterData('Negara'); // Fetch initial country data
    _searchUsers(""); 
  }

  /// Helper to fetch master data based on type
  Future<void> _fetchFilterData(String type) async {
    try {
      if (type == 'Negara') {
         // Direct fetch to avoid Model int casting issues
         final response = await _supabase.from('countries').select().order('name');
         final data = List<Map<String, dynamic>>.from(response);
         print("Jumlah negara yang ditarik: ${data.length}");
         
         if (mounted) setState(() => _countries = data);
      } 
      else if (type == 'Keuskupan' && _selectedCountryId != null) {
         final response = await _supabase.from('dioceses')
             .select()
             .eq('country_id', _selectedCountryId!)
             .order('name');
         final data = List<Map<String, dynamic>>.from(response);
         if (mounted) setState(() => _dioceses = data);
      }
      else if (type == 'Paroki' && _selectedDioceseId != null) {
         // Note: using 'churches' table
         final response = await _supabase.from('churches')
             .select()
             .eq('diocese_id', _selectedDioceseId!)
             .order('name');
         final data = List<Map<String, dynamic>>.from(response);
         if (mounted) setState(() => _churches = data);
      }
    } catch (e) {
      debugPrint("Error fetching $type: $e");
    }
  }

  void _onCountryChanged(String? countryId) {
    setState(() {
      _selectedCountryId = countryId;
      _selectedDioceseId = null;
      _selectedChurchId = null;
      _dioceses = [];
      _churches = [];
    });
    _searchUsers(_searchController.text);
    if (countryId != null) _fetchFilterData('Keuskupan');
  }

  void _onDioceseChanged(String? dioceseId) {
    setState(() {
      _selectedDioceseId = dioceseId;
      _selectedChurchId = null;
      _churches = [];
    });
    _searchUsers(_searchController.text);
    if (dioceseId != null) _fetchFilterData('Paroki');
  }

  void _onChurchChanged(String? churchId) {
    setState(() {
      _selectedChurchId = churchId;
    });
    _searchUsers(_searchController.text);
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _isLoading = true);
    
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // 1. Initial Query
      var dbQuery = _supabase.from('profiles').select();
      
      // 2. Apply Filters
      dbQuery = dbQuery.neq('id', myId); // Exclude self

      if (query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%'); // Search by name
      }

      // Location Filters
      if (_selectedCountryId != null) {
        dbQuery = dbQuery.eq('country_id', _selectedCountryId!);
      }
      if (_selectedDioceseId != null) {
        dbQuery = dbQuery.eq('diocese_id', _selectedDioceseId!);
      }
      if (_selectedChurchId != null) {
        // Assuming profile has church_id column which is UUID/String
        dbQuery = dbQuery.eq('church_id', _selectedChurchId!);
      }

      // 3. Execute
      final data = await dbQuery
          .order('full_name', ascending: true)
          .limit(30);
      
      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("Search Error: $e");
      }
    }
  }

  Future<void> _startChat(Map<String, dynamic> userProfile) async {
    final targetId = userProfile['id'];
    
    try {
      // Use the new service method we created!
      final chatId = await _supabaseService.startChat(targetId);

      if (!mounted) return;

      // Navigate to chat detail
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (_) => SocialChatDetailPage(
            chatId: chatId, 
            opponentProfile: userProfile
          )
        )
      );

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error starting chat: $e")));
    }
  }

  // --- UI Helpers for Names ---
  String _getCountryName() {
    if (_selectedCountryId == null) return "Negara";
    try {
      return _countries.firstWhere((c) => c['id'].toString() == _selectedCountryId)['name'];
    } catch (_) {
      return "Negara";
    }
  }

  String _getDioceseName() {
    if (_selectedDioceseId == null) return "Keuskupan";
    try {
      return _dioceses.firstWhere((d) => d['id'].toString() == _selectedDioceseId)['name'];
    } catch (_) {
      return "Keuskupan";
    }
  }

  String _getChurchName() {
    if (_selectedChurchId == null) return "Paroki";
    try {
      return _churches.firstWhere((c) => c['id'].toString() == _selectedChurchId)['name'];
    } catch (_) {
      return "Paroki";
    }
  }

  // --- Bottom Sheet Filter (Premium) ---
  void _showFilterSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required Function(String?) onSelect,
    bool isLoading = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow fuller height control
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Drag Handle
              Center(
                child: Container(
                  width: 48, height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
                ),
              ),
              const SizedBox(height: 20),
              
              Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              const Divider(height: 1, color: AppColors.surface),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryBrand)),
                )
              else if (items.isEmpty)
                 Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("Tidak ada data", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: 1 + items.length, // +1 for "Semua"
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.surface),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.primaryBrand.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.public, color: AppColors.primaryBrand, size: 20),
                          ),
                          title: Text("Semua (All)", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.primaryBrand, fontSize: 16)),
                          trailing: const Icon(Icons.check_circle_outline, color: AppColors.primaryBrand, size: 20),
                          onTap: () {
                            onSelect(null);
                            Navigator.pop(context);
                          },
                        );
                      }
                      
                      final item = items[index - 1];
                      // Determine if selected (optional, for UI highlight)
                      // Ideally we check if item.id == currentId, but for simplicity generic T checking is harder without passing current ID.
                      // We'll keep it simple and clean.
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        leading: const Icon(Icons.location_on_outlined, color: Colors.grey, size: 22),
                        title: Text(item['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 16, color: AppColors.textPrimary)),
                        onTap: () {
                          // Use toString to safe handle UUID vs int if mixed
                          onSelect(item['id'].toString());
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasFilter = _selectedCountryId != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: TextField(
          controller: _searchController,
          autofocus: false,
          onChanged: (val) => _searchUsers(val),
          decoration: InputDecoration(
            hintText: "Cari pengguna...",
            hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
            border: InputBorder.none,
          ),
          style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12), // Consistent top spacing
                Text(
                  "Filter berdasarkan lokasi",
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Country Filter
                      _buildFilterChip(
                        label: _selectedCountryId != null ? _getCountryName() : "Negara",
                        isActive: _selectedCountryId != null,
                        onTap: () {
                          _showFilterSheet(
                            title: "Pilih Negara",
                            items: _countries,
                            onSelect: (id) => _onCountryChanged(id),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      
                      // Diocese Filter
                      if (_selectedCountryId != null) ...[
                        _buildFilterChip(
                          label: _selectedDioceseId != null ? _getDioceseName() : "Keuskupan",
                          isActive: _selectedDioceseId != null,
                          onTap: () {
                            _showFilterSheet(
                              title: "Pilih Keuskupan",
                              items: _dioceses,
                              onSelect: (id) => _onDioceseChanged(id),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                      ],

                      // Church Filter
                      if (_selectedDioceseId != null) ...[
                        _buildFilterChip(
                          label: _selectedChurchId != null ? _getChurchName() : "Gereja",
                          isActive: _selectedChurchId != null,
                          onTap: () {
                            _showFilterSheet(
                              title: "Pilih Paroki",
                              items: _churches,
                              onSelect: (id) => _onChurchChanged(id),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                      ],
                      
                      // Reset Button (Only if filter actions exist)
                      if (hasFilter)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: InkWell(
                            onTap: () => _onCountryChanged(null),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.black54),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBrand))
          : _searchResults.isEmpty 
              ? Center(child: Text("Pengguna tidak ditemukan", style: GoogleFonts.outfit(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_,__) => const Divider(height: 1, color: AppColors.surface),
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      // Navigation to Profile
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfilePage(userId: user['id'])));
                      },
                      
                      // Avatar
                      leading: SafeNetworkImage(
                        imageUrl: user['avatar_url'],
                        width: 50, height: 50,
                        borderRadius: BorderRadius.circular(100),
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.person,
                      ),
                      
                      // Name
                      title: Text(
                        user['full_name'] ?? "User",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                      ),
                      
                      subtitle: Text(
                         user['role'] != null ? "${user['role'].toString().toUpperCase()}" : "Umat",
                         style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)
                      ),
                      
                      // Chat Icon -> Start Chat
                      trailing: GestureDetector(
                        onTap: () => _startChat(user),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryBrand, size: 20),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildFilterChip({required String label, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryBrand : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? AppColors.primaryBrand : Colors.grey[300]!,
          ),
          boxShadow: isActive ? [
             BoxShadow(color: AppColors.primaryBrand.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                  label.length > 20 ? "${label.substring(0, 18)}..." : label,
              style: GoogleFonts.outfit(
                color: isActive ? Colors.white : AppColors.textPrimary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded, 
              size: 16, 
              color: isActive ? Colors.white : Colors.grey
            ),
          ],
        ),
      ),
    );
  }
}
