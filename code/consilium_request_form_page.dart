import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/pages/consilium/consilium_waiting_page.dart';

class ConsiliumRequestFormPage extends StatefulWidget {
  final String role;

  const ConsiliumRequestFormPage({super.key, required this.role});

  @override
  State<ConsiliumRequestFormPage> createState() => _ConsiliumRequestFormPageState();
}

class _ConsiliumRequestFormPageState extends State<ConsiliumRequestFormPage> {
  // Styles
  static const Color kBackground = Color(0xFF111111);
  static const Color kNeonGreen = Color(0xFFB2FF59);
  static const Color kSurface = Color(0xFF1E1E1E);
  
  // Data
  final _messageController = TextEditingController();
  final List<String> _topics = ["Masalah Pribadi", "Keluarga", "Iman/Keraguan", "Lainnya"];
  String? _selectedTopic;
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submitRequest() async {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih topik konsultasi terlebih dahulu"))
      );
      return;
    }
    if (_messageController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon isi pesan singkat"))
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API Call
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ConsiliumWaitingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Detail Permintaan",
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: kNeonGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: const BoxDecoration(
                       color: Colors.black12,
                       shape: BoxShape.circle
                     ),
                     child: const Icon(Icons.record_voice_over_rounded, color: Colors.black, size: 24),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           "KONSULTASI DENGAN",
                           style: GoogleFonts.outfit(
                             color: Colors.black54,
                             fontSize: 10,
                             fontWeight: FontWeight.bold,
                             letterSpacing: 1.5
                           ),
                         ),
                         Text(
                           widget.role.toUpperCase(),
                           style: GoogleFonts.outfit(
                             color: Colors.black,
                             fontSize: 20,
                             fontWeight: FontWeight.w900,
                           ),
                         ),
                       ],
                     ),
                   )
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 3. Form Section - Topic
            Text(
              "PILIH TOPIK",
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _topics.map((topic) {
                final isSelected = _selectedTopic == topic;
                return ChoiceChip(
                  label: Text(topic),
                  labelStyle: GoogleFonts.outfit(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedTopic = val ? topic : null),
                  backgroundColor: kSurface,
                  selectedColor: kNeonGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                    side: BorderSide(color: isSelected ? kNeonGreen : Colors.white12)
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Form Section - Message
            Text(
              "PESAN SINGKAT",
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 5,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: kSurface,
                hintText: "Ceritakan sedikit tentang apa yang ingin anda bicarakan...",
                hintStyle: GoogleFonts.outfit(color: Colors.white30),
                contentPadding: const EdgeInsets.all(20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kNeonGreen)
                ),
              ),
            ),

            const SizedBox(height: 50),

            // 4. Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNeonGreen,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5)
                      )
                    : Text(
                        "KIRIM PERMINTAAN",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
