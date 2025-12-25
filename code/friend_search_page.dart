import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final _supabase = Supabase.instance.client;
  
  // Filters
  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;
  
  // Names for display
  String? _countryName;
  String? _dioceseName;
  String? _churchName;

  RangeValues _ageRange = const RangeValues(18, 30);

  // Search Results
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  // --- HELPERS: CASADING DROPDOWNS (Reusing Logic pattern) ---
  Future<void> _showSearchModal(String table, String? filterCol, String? filterVal, String title, Function(String id, String name) onSelect) async {
      // 1. Fetch Data
      var query = _supabase.from(table).select('id, name');
      if (filterCol != null && filterVal != null) query = query.eq(filterCol, filterVal);
      final res = await query.order('name');
      final items = List<Map<String, dynamic>>.from(res);

      if (!mounted) return;

      // 2. Show Modal
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.deepViolet,
        isScrollControlled: true,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return ListTile(
                      title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                      onTap: () {
                         onSelect(item['id'].toString(), item['name']);
                         Navigator.pop(context);
                      },
                    );
                  },
                ),
              )
            ],
          ),
        )
      );
  }

  Future<void> _doSearch() async {
    setState(() => _isLoading = true);

    try {
      // Base Query
      var query = _supabase.from('profiles').select();

      // Apply Location Filters
      if (_selectedChurchId != null) {
        query = query.eq('church_id', _selectedChurchId!);
      } else if (_selectedDioceseId != null) {
        query = query.eq('diocese_id', _selectedDioceseId!);
      } else if (_selectedCountryId != null) {
        query = query.eq('country_id', _selectedCountryId!);
      }

      // Execute Query
      final data = await query;
      
      // Client-side Age Filtering (Simpler than raw SQL date math)
      // Standard Age Calc: (Now - BirthDate).years
      final now = DateTime.now();
      final filtered = List<Map<String, dynamic>>.from(data).where((user) {
        if (user['birth_date'] == null) return false;
        final dob = DateTime.parse(user['birth_date']);
        // Age Calc: (DateTime.now() - birth_date).inDays / 365
        final age = (now.difference(dob).inDays / 365).floor();
        return age >= _ageRange.start && age <= _ageRange.end;
      }).toList();

      setState(() => _results = filtered);

    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepViolet,
      appBar: AppBar(
        title: const Text("Cari Teman", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // FILTERS SECTION
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.glassyViolet,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filter Pencarian", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 16),
                  
                  // Location Inputs
                  _buildSelector("Negara", _countryName, () => _showSearchModal('countries', null, null, "Pilih Negara", (id, name) {
                    setState(() { _selectedCountryId = id; _countryName = name; _selectedDioceseId = null; _dioceseName = null; _selectedChurchId = null; _churchName = null; });
                  })),
                  const SizedBox(height: 12),
                  if (_selectedCountryId != null)
                    _buildSelector("Keuskupan", _dioceseName, () => _showSearchModal('dioceses', 'country_id', _selectedCountryId, "Pilih Keuskupan", (id, name) {
                        setState(() { _selectedDioceseId = id; _dioceseName = name; _selectedChurchId = null; _churchName = null; });
                    })),
                  const SizedBox(height: 12),
                   if (_selectedDioceseId != null)
                    _buildSelector("Paroki", _churchName, () => _showSearchModal('churches', 'diocese_id', _selectedDioceseId, "Pilih Paroki", (id, name) {
                        setState(() { _selectedChurchId = id; _churchName = name; });
                    })),
                  
                  const SizedBox(height: 24),
                  
                  // Age Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Rentang Umur", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
                      Text("${_ageRange.start.round()} - ${_ageRange.end.round()} thn", style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.vibrantOrange)),
                    ],
                  ),
                  RangeSlider(
                    values: _ageRange,
                    min: 17, max: 60,
                    divisions: 43,
                    activeColor: AppTheme.vibrantOrange,
                    inactiveColor: Colors.black26,
                    labels: RangeLabels("${_ageRange.start.round()}", "${_ageRange.end.round()}"),
                    onChanged: (vals) => setState(() => _ageRange = vals),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _doSearch,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.vibrantOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text("CARI TEMAN", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // RESULTS
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppTheme.vibrantOrange))
                : _results.isEmpty 
                    ? const Center(child: Text("Hasil pencarian akan tampil di sini.", style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_,__) => const SizedBox(height: 16),
                        itemBuilder: (_, i) {
                          final user = _results[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            tileColor: AppTheme.glassyViolet,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.darkInputFill,
                              child: SafeNetworkImage(
                                imageUrl: user['avatar_url'],
                                width: 40, height: 40,
                                borderRadius: BorderRadius.circular(20),
                                fit: BoxFit.cover,
                                fallbackIcon: Icons.person,
                                iconColor: Colors.white54,
                                fallbackColor: AppTheme.darkInputFill,
                              ),
                            ),
                            title: Text(user['full_name'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: Text((user['role'] ?? "Umat").toString().toUpperCase(), style: const TextStyle(color: AppTheme.vibrantOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSelector(String hint, String? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkInputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value ?? hint, style: TextStyle(color: value == null ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_drop_down, color: AppTheme.vibrantOrange)
          ],
        ),
      ),
    );
  }
}
