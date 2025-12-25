import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConsiliumWaitingPage extends StatelessWidget {
  const ConsiliumWaitingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kNeonGreen = Color(0xFFB2FF59);
    const Color kDarkBg = Color(0xFF111111);

    return Scaffold(
      backgroundColor: kDarkBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty_rounded, size: 80, color: kNeonGreen),
            const SizedBox(height: 24),
            Text(
              "Permintaan Terkirim",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Mohon tunggu sebentar,\nkami sedang menghubungkan anda.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNeonGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("KEMBALI KE HOME", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
