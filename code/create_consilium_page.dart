import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateConsiliumPage extends StatefulWidget {
  const CreateConsiliumPage({super.key});

  @override
  State<CreateConsiliumPage> createState() => _CreateConsiliumPageState();
}

class _CreateConsiliumPageState extends State<CreateConsiliumPage> {
  final _topicController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedRole = 'Bebas'; // Default value
  bool _isLoading = false;

  final List<String> _roleOptions = ['Bebas', 'Pastor', 'Suster', 'Bruder', 'Katekis'];

  // --- DESIGN SYSTEM CONSTANTS (Kulikeun Premium) ---
  static const Color bgNavy = Color(0xFF0B1121);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color textWhite = Colors.white;
  static const Color textGrey = Color(0xFF94A3B8);
  
  static final Color glassInput = Colors.white.withValues(alpha: 0.05);
  static const Color glassBorder = Colors.white12;

  Future<void> _submitTicket() async {
    if (_topicController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text("Mohon isi semua field.", style: GoogleFonts.outfit(color: textWhite)),
           backgroundColor: Colors.redAccent,
           behavior: SnackBarBehavior.floating,
         )
       );
       return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "User not logged in";

      await Supabase.instance.client.from('consilium_requests').insert({
        'user_id': user.id,
        'topic': _topicController.text.trim(),
        'description': _descController.text.trim(),
        'preferred_role': _selectedRole, // Save selected preference
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Permintaan konsultasi dikirim!", style: GoogleFonts.outfit(color: textWhite)), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
        Navigator.pop(context); // Back to list
      }
    } catch (e) {
       debugPrint("Create Ticket Error: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text("Gagal mengirim permintaan.", style: GoogleFonts.outfit(color: textWhite)),
             backgroundColor: Colors.red,
             behavior: SnackBarBehavior.floating,
           )
         );
         setState(() => _isLoading = false);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        title: Text("Buat Konsultasi", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: textWhite)),
        centerTitle: false,
        backgroundColor: bgNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: textWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Topik Masalah", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textWhite)),
            const SizedBox(height: 12),
            _buildInput(_topicController, "Misal: Keraguan Iman, Masalah Keluarga...", 1),
            
            const SizedBox(height: 24),

            // Dropdown Preferensi Konselor
            Text("Ingin Konsultasi Dengan?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textWhite)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: glassInput,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: glassBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRole,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E293B), // Dark slate for popup
                  style: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.bold, fontSize: 16),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: textWhite),
                  items: _roleOptions.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            Text("Deskripsi Singkat", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textWhite)),
            const SizedBox(height: 12),
            _buildInput(_descController, "Ceritakan sedikit tentang apa yang ingin dikonsultasikan...", 5),
            
            const SizedBox(height: 48),
            
            // GRADIENT BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [accentIndigo, accentPurple]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accentIndigo.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: textWhite, strokeWidth: 2))
                      : Text(
                          "KIRIM PERMINTAAN", 
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: textWhite, fontSize: 14, letterSpacing: 1)
                        ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, int lines) {
    return Container(
      decoration: BoxDecoration(
        color: glassInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glassBorder),
      ),
      child: TextField(
        controller: controller,
        maxLines: lines,
        style: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.bold),
        cursorColor: accentIndigo,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
