import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/pages/consilium/chat_screen.dart'; // Correct Import
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';

// Constants defined at file level or inside class if preferred, 
// user asked for them to be defined. Putting them at top of file or inside build.
// Requirement: "Define the missing constants kSignatureGradient and kSignatureShadow at the top of the file."
const kSignatureGradient = LinearGradient(
  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final kSignatureShadow = [
  BoxShadow(
    color: const Color(0xFF8B5CF6).withOpacity(0.3),
    blurRadius: 12,
    offset: const Offset(0, 6),
  )
];

class ConsiliumPage extends StatefulWidget {
  const ConsiliumPage({super.key});

  @override
  State<ConsiliumPage> createState() => _ConsiliumPageState();
}

class _ConsiliumPageState extends State<ConsiliumPage> {
  final _supabase = Supabase.instance.client;
  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final bodyColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final activeCardColor = theme.brightness == Brightness.dark ? Colors.grey[800]! : const Color(0xFFF1F5F9);
    final borderColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const MyCatholicAppBar(
        title: "Consilium",
      ),
      body: SafeArea(
        child: Column(
          children: [
             Expanded(
               child: StreamBuilder<List<Map<String, dynamic>>>(
                 stream: _userId != null 
                    ? _supabase.from('consilium_requests')
                        .stream(primaryKey: ['id'])
                        .eq('user_id', _userId!)
                        .order('created_at', ascending: false)
                    : Stream.value([]),
                 builder: (context, snapshot) {
                   final allRequests = snapshot.data ?? [];
                   
                   final activeList = allRequests.where((r) => r['status'] == 'active').toList();
                   final waitingList = allRequests.where((r) => r['status'] == 'open' || r['status'] == 'waiting').toList();
                   final historyList = allRequests.where((r) => r['status'] == 'closed' || r['status'] == 'completed').toList();

                   return ListView(
                     padding: const EdgeInsets.all(16),
                     children: [
                       // SECTION A: START NEW
                       _buildNewConsultationCard(context, theme, primaryColor, cardColor, titleColor, bodyColor),
                       const SizedBox(height: 24),

                       // SECTION B: ACTIVE / WAITING
                       if (activeList.isNotEmpty || waitingList.isNotEmpty) ...[
                         Text("Permintaan Aktif", style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18)),
                         const SizedBox(height: 12),
                         ...activeList.map((r) => _buildActiveCard(r, kSignatureGradient, kSignatureShadow, primaryColor)),
                         ...waitingList.map((r) => _buildWaitingCard(r, theme, cardColor, primaryColor, titleColor, bodyColor, metaColor, activeCardColor)),
                         const SizedBox(height: 24),
                       ], 

                       // SECTION C: HISTORY
                       Text("Riwayat Konsultasi", style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18)),
                       const SizedBox(height: 12),
                       
                       if (historyList.isEmpty && activeList.isEmpty && waitingList.isEmpty)
                         _buildEmptyHistoryState(metaColor, bodyColor),

                       ...historyList.map((r) => _buildHistoryTile(r, theme, cardColor, primaryColor, titleColor, metaColor, activeCardColor)),
                       
                       // Safe padding at bottom
                       const SizedBox(height: 40),
                     ],
                   );
                 },
               ),
             ),
          ],
        ),
      ),
    );
  }

  // --- SECTION A: NEW CONSULTATION (Glass Card) ---
  Widget _buildNewConsultationCard(BuildContext context, ThemeData theme, Color primary, Color card, Color title, Color body) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.favorite_rounded, color: primary, size: 24), 
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text("Butuh Teman Bicara?", style: GoogleFonts.outfit(color: title, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Ceritakan pergumulanmu kepada Pastor, Suster, atau konselor rohani kami.",
                  style: GoogleFonts.outfit(color: body, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showRoleSelectionSheet(context, theme),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary, 
                      foregroundColor: Colors.white, 
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text("Ajukan Permintaan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SECTION B: CARDS ---
  Widget _buildWaitingCard(Map<String, dynamic> data, ThemeData theme, Color card, Color primary, Color title, Color body, Color meta, Color activeCard) {
    final role = data['preferred_role'] ?? 'Konselor';
    final topic = data['topic'] ?? 'Tanpa Topik';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: activeCard, shape: BoxShape.circle),
                      child: Icon(Icons.hourglass_top_rounded, color: meta, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Menunggu Respons...", style: GoogleFonts.outfit(color: title, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("Topik: $topic", style: GoogleFonts.outfit(color: body, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: activeCard, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    "Saat ini belum ada $role yang tersedia. Permintaanmu telah masuk antrian dan akan segera direspon.",
                    style: GoogleFonts.outfit(color: meta, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard(Map<String, dynamic> data, Gradient gradient, List<BoxShadow> shadow, Color primary) {
    final partnerName = data['partner_name'] ?? "Konselor"; 
    final topic = data['topic'] ?? "Sesi Rohani";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            radius: 24,
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partnerName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("Chat Aktif • $topic", style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => ConsiliumChatScreen( // Updated to new class name
                  partnerId: data['partner_id'] ?? 'unknown', // Pass ID
                  partnerName: partnerName,
                  partnerAvatar: null,
               )));
            },
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            icon: Icon(Icons.chat_bubble_rounded, color: primary, size: 20),
          )
        ],
      ),
    );
  }

  // --- SECTION C: HISTORY ---
  Widget _buildHistoryTile(Map<String, dynamic> data, ThemeData theme, Color card, Color primary, Color title, Color meta, Color activeCard) {
    final topic = data['topic'] ?? "Konsultasi";
    final date = data['created_at'] != null 
        ? timeago.format(DateTime.parse(data['created_at']), locale: 'id') 
        : "-";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
           padding: const EdgeInsets.all(10),
           decoration: BoxDecoration(color: activeCard, shape: BoxShape.circle),
           child: Icon(Icons.history_edu_rounded, color: meta),
        ),
        title: Text(topic, style: GoogleFonts.outfit(color: title, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text("$date • Selesai", style: GoogleFonts.outfit(color: meta, fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: meta),
        onTap: () {
           // View Chat History
        },
      ),
    );
  }

  Widget _buildEmptyHistoryState(Color meta, Color body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: meta),
            const SizedBox(height: 12),
            Text("Belum ada riwayat", style: GoogleFonts.outfit(color: body)),
          ],
        ),
      ),
    );
  }


  // --- LOGIC: NEW REQUEST MODAL ---
  void _showRoleSelectionSheet(BuildContext context, ThemeData theme) {
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dividerColor = theme.dividerColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, 
            left: 20, right: 20, top: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: dividerColor, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text("Siapa yang ingin kamu temui?", style: GoogleFonts.outfit(color: titleColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              // Roles Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRoleOption(context, theme, "Pastor", Icons.church),
                  _buildRoleOption(context, theme, "Suster", Icons.favorite), // Generic Icon
                  _buildRoleOption(context, theme, "Bruder", Icons.handshake),
                  _buildRoleOption(context, theme, "Katekis", Icons.school),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  Widget _buildRoleOption(BuildContext context, ThemeData theme, String label, IconData icon) {
    final activeCard = theme.brightness == Brightness.dark ? Colors.grey[800]! : const Color(0xFFF1F5F9);
    final borderColor = theme.dividerColor;
    final bodyColor = theme.textTheme.bodyMedium?.color;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showTopicInputSheet(context, theme, label);
      },
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: activeCard,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor)
            ),
            child: Icon(icon, color: bodyColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.outfit(color: bodyColor, fontSize: 13, fontWeight: FontWeight.w500))
        ],
      ),
    );
  }

  void _showTopicInputSheet(BuildContext context, ThemeData theme, String role) {
    final TextEditingController topicController = TextEditingController();
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final cardColor = theme.cardColor;
    final primaryColor = theme.primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
           padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Topik Konsultasi ($role)", style: GoogleFonts.outfit(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: topicController,
                autofocus: true,
                style: GoogleFonts.outfit(color: titleColor),
                decoration: InputDecoration(
                  hintText: "Contoh: Masalah doa, keraguan iman...",
                  hintStyle: GoogleFonts.outfit(color: metaColor),
                  filled: true,
                  fillColor: cardColor, // Or surface secondary
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                     if (topicController.text.trim().isNotEmpty) {
                       _submitRequest(role, topicController.text.trim(), primaryColor);
                       Navigator.pop(context);
                     }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: Text("Kirim Permintaan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Future<void> _submitRequest(String role, String topic, Color primary) async {
    try {
      if (_userId == null) return;
      
      await _supabase.from('consilium_requests').insert({
        'user_id': _userId,
        'topic': topic,
        'preferred_role': role,
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           backgroundColor: primary,
           content: Text("Permintaan terkirim! Menunggu respons $role.", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
         ));
      }
    } catch (e) {
      debugPrint("Error submitting request: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mode Demo: Permintaan Simulasi Terkirim")));
      }
    }
  }

}
