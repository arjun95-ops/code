import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/services/supabase_service.dart';
import 'package:mychatolic_app/models/schedule.dart';

class ChurchDetailPage extends StatefulWidget {
  final Map<String, dynamic> churchData;

  const ChurchDetailPage({super.key, required this.churchData});

  @override
  State<ChurchDetailPage> createState() => _ChurchDetailPageState();
}

class _ChurchDetailPageState extends State<ChurchDetailPage> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;

  // Grouped Data: Key = Day Name (e.g. "Minggu"), Value = List of Schedules
  Map<String, List<Schedule>> _schedulesByDay = {};

  // --- DESIGN SYSTEM CONSTANTS ---
  static const Color kBackgroundMain = Color(0xFFFFFFFF); // Putih Bersih
  static const Color kSurfaceCard = Color(0xFFF5F5F5);    // Abu sangat muda
  static const Color kPrimaryBrand = Color(0xFF0088CC);   // Primary Blue
  static const Color kTextPrimary = Color(0xFF000000);
  static const Color kTextSecondary = Color(0xFF555555);

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    try {
      final churchId = widget.churchData['id']?.toString();
      if (churchId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Fetch schedules using the Service
      final schedules = await _supabaseService.fetchSchedules(churchId);

      // Group by Day Text
      final grouped = <String, List<Schedule>>{};
      for (var s in schedules) {
        if (!grouped.containsKey(s.dayName)) grouped[s.dayName] = [];
        grouped[s.dayName]!.add(s);
      }

      if (mounted) {
        setState(() {
          _schedulesByDay = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching schedules: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchMap() async {
    final lat = widget.churchData['latitude'];
    final lng = widget.churchData['longitude'];
    if (lat != null && lng != null) {
      final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lokasi tidak tersedia")));
    }
  }

  Future<void> _launchExternal(String? url) async {
    if (url == null || url.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link tidak tersedia")));
       return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch URL")));
    }
  }

  // --- RADAR FEATURE ---
  void _showCreateRadarModal(Schedule schedule) {
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Buat Radar Misa", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "Misa ${schedule.dayName}, ${schedule.timeStart}",
                    style: GoogleFonts.outfit(color: kTextSecondary, fontSize: 16),
                  ),
                   if (schedule.language != null)
                    Text(
                      schedule.language!,
                      style: GoogleFonts.outfit(color: kTextSecondary, fontSize: 14),
                    ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: "Catatan (Opsional)",
                      hintText: "Contoh: Kumpul di parkiran depan...",
                      filled: true,
                      fillColor: kSurfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          await _supabaseService.createRadarFromSchedule(
                            scheduleId: schedule.id,
                            notes: notesController.text,
                          );
                          if (context.mounted) {
                             Navigator.pop(context); // Close Modal
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                               content: Text("Radar berhasil dibuat! Teman-temanmu akan diberitahu."),
                               backgroundColor: Colors.green,
                             ));
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBrand,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text("Buat Radar", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Correctly accessing church data
    final name = widget.churchData['name'] ?? "Gereja";
    final address = widget.churchData['address'] ?? "Alamat tidak tersedia";
    final imageUrl = widget.churchData['image_url'];
    final socialUrl = widget.churchData['social_media_url'];
    final webUrl = widget.churchData['website_url'];

    return Scaffold(
      backgroundColor: kBackgroundMain, 
      body: CustomScrollView(
        slivers: [
          // 1. HEADER IMAGE (Expandable)
          SliverAppBar(
            expandedHeight: 250,
            backgroundColor: kBackgroundMain,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: kBackgroundMain,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null 
                ? SafeNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fallbackColor: kSurfaceCard,
                  )
                : Container(
                    color: kSurfaceCard, 
                    child: const Icon(Icons.church, size: 64, color: Colors.grey)
                  ),
            ),
          ),

          // 2. CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE & ADDRESS
                  Text(
                    name,
                    style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: kTextPrimary)
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Icon(Icons.location_on_outlined, size: 20, color: kTextSecondary),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           address, 
                           style: GoogleFonts.outfit(fontSize: 14, color: kTextSecondary, height: 1.4),
                         )
                       ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ACTION BUTTONS
                  Row(
                    children: [
                       Expanded(child: _buildActionButton(Icons.map, "Peta", _launchMap)),
                       const SizedBox(width: 12),
                       Expanded(child: _buildActionButton(Icons.public, "Website", () => _launchExternal(webUrl ?? socialUrl))),
                    ],
                  ),
                  const SizedBox(height: 32),

                  
                  // --- SCHEDULE LIST ---
                  Text(
                    "Jadwal Misa",
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
                  ),
                  const SizedBox(height: 16),

                  if (_isLoading)
                     const Padding(
                       padding: EdgeInsets.only(top: 20),
                       child: Center(child: CircularProgressIndicator(color: kPrimaryBrand)),
                     )
                  else if (_schedulesByDay.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: kSurfaceCard, borderRadius: BorderRadius.circular(12)),
                        child: Center(
                          child: Text("Jadwal belum tersedia", style: GoogleFonts.outfit(color: kTextSecondary)),
                        ),
                      )
                  else
                     // Render Schedule Groups
                     ..._schedulesByDay.entries.map((entry) {
                       return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // Day Header
                           Padding(
                             padding: const EdgeInsets.only(bottom: 12.0),
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: kTextPrimary.withOpacity(0.05),
                                 borderRadius: BorderRadius.circular(8)
                               ),
                               child: Text(
                                 entry.key, 
                                 style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: kTextPrimary)
                               ),
                             ),
                           ),
                           
                           // Grid of Cards
                           Wrap(
                             spacing: 12,
                             runSpacing: 12,
                             children: entry.value.map((s) => _buildScheduleCard(s)).toList(),
                           ),
                           const SizedBox(height: 24),
                         ],
                       );
                     }).toList(),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: kPrimaryBrand, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryBrand,
        side: const BorderSide(color: kPrimaryBrand),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildScheduleCard(Schedule s) {
    final time = s.timeStart.length > 5 ? s.timeStart.substring(0, 5) : s.timeStart;
    final label = s.language ?? "Umum";

    return Container(
      width: 155, // Fixed width card
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time, 
                style: GoogleFonts.outfit(color: kPrimaryBrand, fontWeight: FontWeight.bold, fontSize: 22)
              ),
              // ADD RADAR BUTTON (+)
              InkWell(
                onTap: () => _showCreateRadarModal(s),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kPrimaryBrand, // Solid Blue
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: kPrimaryBrand.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                  ),
                  child: const Icon(Icons.add, size: 18, color: Colors.white),
                ),
              )
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label, 
            style: GoogleFonts.outfit(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.w500), 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis
          ),
        ],
      ),
    );
  }
}
