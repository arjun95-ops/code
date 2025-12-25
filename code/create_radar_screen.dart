import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/schedule.dart';
import '../services/supabase_service.dart';

class CreateRadarScreen extends StatefulWidget {
  const CreateRadarScreen({super.key});

  @override
  State<CreateRadarScreen> createState() => _CreateRadarScreenState();
}

class _CreateRadarScreenState extends State<CreateRadarScreen> {
  final _supabase = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();
  
  // Theme Colors (Premium)
  static const Color primaryBrand = Color(0xFF0088CC);
  static const Color bgSurface = Color(0xFFF9FAFB);

  // State
  int _currentStep = 0; // 0: Lokasi, 1: Waktu, 2: Detail
  bool _isLoading = false;

  // Data
  List<Schedule> _schedules = []; // Using Model

  // Selections
  String? _selectedCountry;
  String? _selectedDioceseId; 
  String? _selectedDioceseName; 
  String? _selectedChurchId; 
  Map<String, dynamic>? _selectedChurch;
  Schedule? _selectedSchedule; // Using Model
  DateTime? _calculatedScheduleDate;

  // Inputs
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Controllers for "Action Cards" display
  final TextEditingController _countryDisplayCtrl = TextEditingController();
  final TextEditingController _dioceseDisplayCtrl = TextEditingController();
  final TextEditingController _churchDisplayCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _countryDisplayCtrl.dispose();
    _dioceseDisplayCtrl.dispose();
    _churchDisplayCtrl.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _fetchSchedules(String churchId) async {
    setState(() => _isLoading = true);
    try {
      final schedules = await _supabaseService.fetchSchedules(churchId);
      
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _selectedSchedule = null;
          _calculatedScheduleDate = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal jadwal: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  DateTime _calculateNextMassDate(String dayName, String timeStr) {
    final Map<String, int> dayMap = {
      'Senin': DateTime.monday, 'Selasa': DateTime.tuesday, 'Rabu': DateTime.wednesday,
      'Kamis': DateTime.thursday, 'Jumat': DateTime.friday, 'Sabtu': DateTime.saturday,
      'Minggu': DateTime.sunday,
    };

    final int targetWeekday = dayMap[dayName] ?? DateTime.sunday;
    final now = DateTime.now();
    
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    int daysToAdd = (targetWeekday - now.weekday + 7) % 7;
    
    // If today is the day but time passed, move to next week
    if (daysToAdd == 0) {
       final timeNow = now.hour * 60 + now.minute;
       final timeMass = hour * 60 + minute;
       if (timeNow > timeMass) daysToAdd = 7;
    }
    
    DateTime candidate = DateTime(now.year, now.month, now.day + daysToAdd, hour, minute);
    return candidate;
  }

  Future<void> _submitRadar() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul Radar wajib diisi!')));
      return;
    }

    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final chatRes = await _supabase.from('social_chats').insert({
        'is_group': true,
        'group_name': _titleController.text,
        'created_by': user.id,
      }).select().single();
      
      final String chatId = chatRes['id'];

      final churchIdToUse = _selectedChurchId ?? _selectedChurch!['id'];

      await _supabase.from('radars').insert({
        'user_id': user.id,
        'title': _titleController.text,
        'description': _descController.text,
        'church_id': churchIdToUse,
        'schedule_time': _calculatedScheduleDate!.toIso8601String(),
        'chat_group_id': chatId,
        'status': 'active',
        'type': 'group',
      });

      await _supabase.from('chat_members').insert({
        'chat_id': chatId,
        'user_id': user.id,
        'role': 'admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Radar berhasil dibuat!')));
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      final hasChurchText = _churchDisplayCtrl.text.isNotEmpty;
      final hasChurchId = _selectedChurchId != null || _selectedChurch != null;

      if (!hasChurchId && !hasChurchText) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih gereja dulu!")));
        return;
      }
      
      if (!hasChurchId && hasChurchText) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data gereja tidak valid. Silakan pilih ulang.")));
        return;
      }

      if (_schedules.isEmpty && hasChurchId) {
        final id = _selectedChurchId ?? _selectedChurch!['id'];
        await _fetchSchedules(id);
      }
    }

    if (_currentStep == 1 && _selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih jadwal dulu!")));
      return;
    }
    
    if (_currentStep == 2) {
      _submitRadar();
    } else {
      if (mounted) setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _showSearchableSelection({
    required String title,
    required String tableName,
    required Function(Map<String, dynamic>) onSelect,
    String? filterColumn,
    dynamic filterValue,
    List<String>? dummyData
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchableListModal(
        title: title,
        tableName: tableName,
        onSelect: onSelect,
        supabase: _supabase,
        filterColumn: filterColumn,
        filterValue: filterValue,
        dummyData: dummyData,
      ),
    );
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        title: Text("Buat Radar Baru", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildCustomProgress(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_currentStep == 0) _buildStepOneContent(),
                  if (_currentStep == 1) _buildStepTwoContent(),
                  if (_currentStep == 2) _buildStepThreeContent(),
                  
                  const SizedBox(height: 32),
                  
                  // Navigation Buttons
                  Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _prevStep,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text("Kembali", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBrand,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_currentStep == 2 ? "Publikasikan" : "Lanjut", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomProgress() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          return Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 32 : 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive || isCompleted ? primaryBrand : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              if (index < 2) const SizedBox(width: 8),
            ],
          );
        }),
      ),
    );
  }

  // --- STEPS ---

  Widget _buildStepOneContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Pilih Lokasi", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Text("Tentukan gereja tempat misa akan diadakan.", style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 32),

        _buildActionCard(
          icon: Icons.public,
          label: "Negara",
          value: _countryDisplayCtrl.text.isEmpty ? "Pilih Negara" : _countryDisplayCtrl.text,
          isPlaceholder: _countryDisplayCtrl.text.isEmpty,
          onTap: () {
             _showSearchableSelection(
                title: "Pilih Negara",
                tableName: 'countries',
                onSelect: (item) {
                  setState(() {
                    _selectedCountry = item['id'].toString();
                    _countryDisplayCtrl.text = item['name'];
                    
                    _selectedDioceseId = null;
                    _selectedDioceseName = null;
                    _dioceseDisplayCtrl.clear();
                    _selectedChurchId = null;
                    _selectedChurch = null;
                    _churchDisplayCtrl.clear();
                  });
                }
             );
          }
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.account_balance,
          label: "Keuskupan",
          value: _dioceseDisplayCtrl.text.isEmpty ? "Pilih Keuskupan" : _dioceseDisplayCtrl.text,
          isPlaceholder: _dioceseDisplayCtrl.text.isEmpty,
          enabled: _selectedCountry != null,
          onTap: () {
            _showSearchableSelection(
                title: "Pilih Keuskupan",
                tableName: 'dioceses',
                filterColumn: 'country_id', 
                onSelect: (item) {
                  setState(() {
                    _selectedDioceseId = item['id'].toString();
                    _selectedDioceseName = item['name'];
                    _dioceseDisplayCtrl.text = item['name'];

                    _selectedChurchId = null;
                    _selectedChurch = null;
                    _churchDisplayCtrl.clear();
                  });
                }
             );
          }
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.church,
          label: "Gereja / Paroki",
          value: _churchDisplayCtrl.text.isEmpty ? "Pilih Gereja" : _churchDisplayCtrl.text,
          isPlaceholder: _churchDisplayCtrl.text.isEmpty,
          enabled: _selectedDioceseId != null,
          onTap: () {
            _showSearchableSelection(
                title: "Pilih Gereja",
                tableName: 'churches',
                filterColumn: 'diocese_id',
                filterValue: _selectedDioceseId,
                onSelect: (item) {
                  setState(() {
                    _selectedChurch = item;
                    _selectedChurchId = item['id'].toString();
                    _churchDisplayCtrl.text = item['name'];
                  });
                }
             );
          }
        ),
      ],
    );
  }

  Widget _buildStepTwoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Pilih Jadwal", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Text("Pilih jadwal misa dari ${_selectedChurch?['name'] ?? 'Gereja'}.", style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 32),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_schedules.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text("Tidak ada jadwal tersedia.", style: GoogleFonts.outfit(color: Colors.grey)),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12, runSpacing: 12,
            children: _schedules.map((schedule) {
              final isSelected = _selectedSchedule == schedule;
              return GestureDetector(
                onTap: () {
                   setState(() {
                    _selectedSchedule = schedule;
                    _calculatedScheduleDate = _calculateNextMassDate(schedule.dayName, schedule.timeStart);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryBrand.withOpacity(0.1) : Colors.white,
                    border: Border.all(color: isSelected ? primaryBrand : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                  ),
                  child: Column(
                    children: [
                      Text(schedule.dayName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isSelected ? primaryBrand : Colors.black87)),
                      Text(schedule.timeStart.substring(0, 5), style: GoogleFonts.outfit(color: isSelected ? primaryBrand : Colors.grey)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        if (_calculatedScheduleDate != null) ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              border: Border.all(color: primaryBrand.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: primaryBrand.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.event_available, color: primaryBrand),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Jadwal Terpilih:", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat("EEEE, d MMMM y • HH:mm", "id_ID").format(_calculatedScheduleDate!),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                )
              ],
            ),
          )
        ]
      ],
    );
  }

  Widget _buildStepThreeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Detail Radar", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Text("Berikan judul dan deskripsi untuk radar ini.", style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 32),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
               TextField(
                controller: _titleController,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "Judul Radar",
                  labelStyle: GoogleFonts.outfit(color: Colors.grey),
                  hintText: "Contoh: Misa Bareng OMK",
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.title, color: primaryBrand),
                ),
              ),
              Divider(height: 32, color: Colors.grey.shade100),
              TextField(
                controller: _descController,
                maxLines: 4,
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  labelText: "Deskripsi",
                  labelStyle: GoogleFonts.outfit(color: Colors.grey),
                  hintText: "Tambahkan informasi detail...",
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.description_outlined, color: primaryBrand),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isPlaceholder,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             if (enabled) 
               BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enabled ? primaryBrand.withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: enabled ? primaryBrand : Colors.grey, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text(
                    value, 
                    style: GoogleFonts.outfit(
                      fontSize: 16, 
                      fontWeight: FontWeight.w600, 
                      color: isPlaceholder ? Colors.grey.shade400 : (enabled ? Colors.black87 : Colors.grey)
                    )
                  ),
                ],
              ),
            ),
            if (enabled)
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

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
        
        if (widget.filterColumn != null && widget.filterValue != null) {
            dbQuery = dbQuery.eq(widget.filterColumn!, widget.filterValue);
        }
        
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(widget.title, style: GoogleFonts.outfit(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 24),

          TextField(
            controller: _searchController,
            onChanged: _performSearch,
            style: GoogleFonts.outfit(color: Colors.black),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              hintText: "Cari ${widget.title}...",
              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF0F2F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBrand, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: primaryBrand))
              : _results.isEmpty 
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("Tidak ditemukan", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          title: Text(item['name'], style: GoogleFonts.outfit(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
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
