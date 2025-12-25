import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/services/supabase_service.dart';

class CreateInvitePage extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const CreateInvitePage({
    super.key, 
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<CreateInvitePage> createState() => _CreateInvitePageState();
}

class _CreateInvitePageState extends State<CreateInvitePage> {
  final SupabaseService _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;

  // Controllers
  final TextEditingController _countryController = TextEditingController(text: "Indonesia");
  final TextEditingController _dioceseController = TextEditingController();
  final TextEditingController _churchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  // Selected IDs (UUIDs)
  String? _selectedCountryId;
  String? _selectedDioceseId; // UUID
  String? _selectedChurchId; // UUID
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isLoading = false;

  // Design Constants
  static const Color primaryBrand = Color(0xFF0088CC);
  static const Color bgMain = Color(0xFFFFFFFF);
  static const Color bgSurface = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF555555);

  @override
  void initState() {
    super.initState();
    // Pre-load Indonesia if possible, or just rely on user interaction
    _performReverseLookup();
  }

  Future<void> _performReverseLookup() async {
     try {
        if (_countryController.text.isNotEmpty) {
          final cData = await _supabase
              .from('countries')
              .select('id')
              .ilike('name', _countryController.text)
              .maybeSingle();
          if (cData != null && mounted) {
             setState(() => _selectedCountryId = cData['id'].toString());
          }
        }
     } catch (e) {
       debugPrint("Reverse lookup failed: $e");
     }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
           data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBrand,
              onPrimary: Colors.white,
              surface: bgMain,
              onSurface: textPrimary
            ),
            dialogBackgroundColor: bgMain,
          ),
          child: child!,
        );
      }
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
       builder: (context, child) {
        return Theme(
           data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBrand,
              onPrimary: Colors.white,
              surface: bgMain,
              onSurface: textPrimary
            ),
            dialogBackgroundColor: bgMain,
          ),
          child: child!,
        );
      }
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submitInvite() async {
    if (_selectedChurchId == null || _churchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih Gereja terlebih dahulu!")));
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tentukan Waktu Misa!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final DateTime finalSchedule = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await _supabaseService.createPersonalRadar(
        targetUserId: widget.targetUserId,
        churchId: _selectedChurchId!,
        churchName: _churchController.text,
        scheduleTime: finalSchedule,
        message: _messageController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Undangan ke ${widget.targetUserName} Berhasil Dikirim!"), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim undangan: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SEARCHABLE MODAL HELPER ---
  void _showSearchableSelection({
    required String title,
    required String tableName,
    required Function(Map<String, dynamic>) onSelect,
    String? filterColumn,
    dynamic filterValue,
    List<String>? dummyData, 
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgMain,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return _SearchableListModal(
          title: title,
          tableName: tableName,
          onSelect: onSelect,
          supabase: _supabase,
          filterColumn: filterColumn,
          filterValue: filterValue,
          dummyData: dummyData,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      // STICKY BOTTOM BUTTON
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitInvite,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrand,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : Text("KIRIM UNDANGAN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1, color: Colors.white)),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false, // Let content go behind bottom nav for smooth scroll if needed, but here we have a fixed bottom bar
        child: Column(
          children: [
            // --- MODERN HEADER ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              color: const Color(0xFFF9FAFB),
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   GestureDetector(
                     onTap: () => Navigator.pop(context),
                     child: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                       child: const Icon(Icons.close, color: textPrimary, size: 20),
                     ),
                   ),
                   const SizedBox(height: 24),
                   Text("Ajak Misa", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary)),
                   const SizedBox(height: 6),
                   Text("Undang ${widget.targetUserName} untuk misa bersama", style: GoogleFonts.outfit(fontSize: 15, color: textSecondary)),
                 ],
              ),
            ),

            // --- SCROLLABLE CONTENT ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("LOKASI"),
                    const SizedBox(height: 12),
                    
                    // 1. COUNTRY
                    _buildActionCard(
                      label: "Negara",
                      value: _countryController.text,
                      icon: Icons.public,
                      onTap: () {
                        _showSearchableSelection(
                          title: "Pilih Negara",
                          tableName: "countries",
                          filterColumn: null,
                          filterValue: null,
                          onSelect: (item) {
                            setState(() {
                              _countryController.text = item['name'];
                              _selectedCountryId = item['id'].toString();
                              // Cascading Reset
                              _dioceseController.clear();
                              _selectedDioceseId = null;
                              _churchController.clear();
                              _selectedChurchId = null;
                            });
                          }
                        );
                      }
                    ),
                    const SizedBox(height: 12),

                    // 2. DIOCESE
                    _buildActionCard(
                      label: "Keuskupan",
                      value: _dioceseController.text.isEmpty ? "Pilih Keuskupan" : _dioceseController.text,
                      icon: Icons.account_balance,
                      isPlaceholder: _dioceseController.text.isEmpty,
                      onTap: () {
                        if (_selectedCountryId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih Negara Terlebih Dahulu")));
                          return;
                        }
                        _showSearchableSelection(
                          title: "Pilih Keuskupan",
                          tableName: "dioceses",
                          filterColumn: "country_id",
                          filterValue: _selectedCountryId,
                          onSelect: (item) {
                            setState(() {
                               _dioceseController.text = item['name'];
                               _selectedDioceseId = item['id'].toString();
                               // Cascading Reset
                               _churchController.clear();
                               _selectedChurchId = null;
                            });
                          }
                        );
                      }
                    ),
                    const SizedBox(height: 12),

                    // 3. CHURCH
                    _buildActionCard(
                      label: "Gereja / Paroki",
                      value: _churchController.text.isEmpty ? "Pilih Gereja" : _churchController.text,
                      icon: Icons.church,
                      isPlaceholder: _churchController.text.isEmpty,
                      onTap: () {
                         if (_selectedDioceseId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih Keuskupan Terlebih Dahulu")));
                          return;
                        }
                        _showSearchableSelection(
                          title: "Pilih Gereja",
                          tableName: "churches", 
                          filterColumn: "diocese_id", 
                          filterValue: _selectedDioceseId,
                          onSelect: (item) {
                             setState(() {
                               _churchController.text = item['name'];
                               _selectedChurchId = item['id'].toString();
                             });
                          }
                        );
                      }
                    ),

                    const SizedBox(height: 32),
                    _buildSectionTitle("WAKTU"),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            label: "Tanggal", 
                            value: _selectedDate == null ? "Tanggal" : DateFormat("dd MMM").format(_selectedDate!),
                            icon: Icons.calendar_today,
                            isPlaceholder: _selectedDate == null,
                            onTap: _pickDate
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            label: "Jam", 
                            value: _selectedTime == null ? "Jam" : _selectedTime!.format(context),
                            icon: Icons.access_time,
                            isPlaceholder: _selectedTime == null,
                            onTap: _pickTime
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    _buildSectionTitle("PESAN"),
                    const SizedBox(height: 12),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 3,
                        style: GoogleFonts.outfit(color: textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "Tulis pesan singkat (opsional)...",
                          hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title, 
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)
      ),
    );
  }

  // REPLACEMENT FOR _buildSearchableField & _buildClickableField
  // Unified "Action Card" Design
  Widget _buildActionCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: primaryBrand, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.outfit(color: isPlaceholder ? Colors.grey.shade400 : textPrimary, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 16),
          ],
        ),
      ),
    );
  }

  // Helper kept for compatibility if needed, but unused in new UI
  Widget _buildSearchableField(String label, TextEditingController controller, VoidCallback onTap) {
      return Container(); // Deprecated in this view
  }
  Widget _buildClickableField(String label, String value, IconData icon, VoidCallback onTap) {
      return Container(); // Deprecated
  }
  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
      return Container(); // Deprecated
  }
}

// --- SEARCHABLE MODAL ---
class _SearchableListModal extends StatefulWidget {
  final String title;
  final String tableName;
  final Function(Map<String, dynamic>) onSelect;
  final SupabaseClient supabase;
  final List<String>? dummyData; 
  final String? filterColumn;
  final dynamic filterValue;

  const _SearchableListModal({required this.title, required this.tableName, required this.onSelect, required this.supabase, this.dummyData, this.filterColumn, this.filterValue});

  @override
  State<_SearchableListModal> createState() => _SearchableListModalState();
}

class _SearchableListModalState extends State<_SearchableListModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = []; 
  bool _loading = false;
  Timer? _debounce;
  
  static const Color primaryBrand = Color(0xFF0088CC);
  // static const Color bgSurface = Color(0xFFF5F5F5); // Replaced with new color for search bar: 0xFFF0F2F5

  @override
  void initState() {
    super.initState();
    _performSearch("");
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _loading = true);
      try {
        var dbQuery = widget.supabase.from(widget.tableName).select('id, name'); 
        
        // CASCADING: Only apply filter if value is valid (Not Null)
        if (widget.filterColumn != null && widget.filterValue != null) {
            dbQuery = dbQuery.eq(widget.filterColumn!, widget.filterValue);
        }
        
        // SPECIAL FILTER: If table is 'churches', only show parishes
        if (widget.tableName == 'churches') {
            dbQuery = dbQuery.eq('type', 'parish');
        }

        final data = await dbQuery
            .ilike('name', '%$query%')
            .limit(20);
        
        if (mounted) setState(() => _results = List<Map<String, dynamic>>.from(data));
        
      } catch (e) {
        debugPrint("Error fetching data: $e");
        if (mounted) setState(() {
          if (widget.dummyData != null) {
             _results = widget.dummyData!
                 .where((element) => element.toLowerCase().contains(query.toLowerCase()))
                 .map((e) => {'id': 'dummy-id', 'name': e}) // Dummy String ID
                 .toList();
          } else {
             _results = [];
          }
        });
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), // Modified top padding
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)) // Increased radius
      ),
      child: Column(
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // 2. Header Title (Centered, Bold, No Close Button)
          Text(
            widget.title,
            style: GoogleFonts.outfit(
              color: Colors.black, 
              fontSize: 20, 
              fontWeight: FontWeight.bold
            ),
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 24),

          // 3. Modern Search Bar
          TextField(
            controller: _searchController,
            onChanged: _performSearch,
            style: GoogleFonts.outfit(color: Colors.black),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              hintText: "Cari ${widget.title}...",
              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF0F2F5), // Soft grey
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), // No border
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBrand, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          
          // 4. List Items
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: primaryBrand))
              : _results.isEmpty 
                  // 5. Empty State
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("Tidak ditemukan", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Clean padding
                          title: Text(
                            item['name'], 
                            style: GoogleFonts.outfit(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)
                          ),
                          trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                          onTap: () {
                            widget.onSelect(item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
