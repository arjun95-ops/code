import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({super.key});

  // --- DESIGN SYSTEM CONSTANTS (Kulikeun Premium) ---
  static const Color bgNavy = Color(0xFF0B1121);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color textWhite = Color(0xE6FFFFFF); // ~90% opacity (Reader Friendly)
  static const Color textGrey = Color(0xFF94A3B8);
  static const Color glassCard = Color(0x0DFFFFFF); // ~5% opacity
  static const Color glassBorder = Colors.white12;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgNavy,
      body: CustomScrollView(
        slivers: [
          // 1. COLLAPSING HEADER
          SliverAppBar(
            backgroundColor: bgNavy,
            expandedHeight: 300.0,
            pinned: true,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: glassBorder)
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: null, // Title is in the body to allow large serif font
              background: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(
                    imageUrl: "https://images.unsplash.com/photo-1543791959-12b3f543282a?q=80&w=2070&auto=format&fit=crop",
                    fit: BoxFit.cover,
                  ),
                  // Gradient Overlay for text readability transition
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          bgNavy.withValues(alpha: 0.1),
                          bgNavy.withValues(alpha: 0.8),
                          bgNavy
                        ],
                        stops: const [0.0, 0.5, 0.8, 1.0]
                      )
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. CONTENT BODY
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // TITLE (Serif, Large)
                   Text(
                     "Makna Adven bagi Keluarga Modern",
                     style: GoogleFonts.playfairDisplay( // Classy Serif
                       fontSize: 32,
                       fontWeight: FontWeight.bold,
                       color: Colors.white,
                       height: 1.2
                     ),
                   ),
                   const SizedBox(height: 20),

                   // METADATA ROW
                   Row(
                     children: [
                       Container(
                         width: 40, height: 40,
                         decoration: const BoxDecoration(shape: BoxShape.circle),
                         child: const SafeNetworkImage(
                           imageUrl: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=2070&auto=format&fit=crop",
                           width: 40, height: 40,
                           borderRadius: BorderRadius.all(Radius.circular(20)),
                           fit: BoxFit.cover,
                         ),
                       ),
                       const SizedBox(width: 12),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text("Romo Andalas, SJ", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                           Text("17 Des 2024 • 5 min baca", style: GoogleFonts.outfit(color: textGrey, fontSize: 12)),
                         ],
                       )
                     ],
                   ),

                   const SizedBox(height: 24),
                   Divider(color: glassBorder),
                   const SizedBox(height: 24),

                   // BODY TEXT
                   Text(
                     "Masa Adven adalah masa penantian yang penuh sukacita. Di tengah kesibukan dunia modern yang serba cepat, seringkali kita lupa untuk berhenti sejenak dan merenungkan makna sejati dari kedatangan Kristus.\n\nBagi keluarga Katolik di era digital ini, tantangan terbesar adalah menjaga kehangatan iman di tengah gempuran notifikasi dan deadline pekerjaan. Adven mengajak kita untuk 'log out' sejenak dari kebisingan dunia dan 'log in' kembali ke dalam keheningan hati.\n\nTradisi menyalakan lilin Korona Adven bukan sekadar ritual tahunan, melainkan simbol harapan yang harus kita nyalakan setiap hari di meja makan keluarga kita. Saat lilin pertama dinyalakan, kita diajak untuk menjadi terang bagi sesama.",
                     style: GoogleFonts.sourceSerif4( // Readable Serif/Sans Hybrid for body
                       fontSize: 18,
                       height: 1.8,
                       color: textWhite
                     ),
                   ),
                   
                   const SizedBox(height: 16),
                   
                   Text(
                     "Mari kita jadikan Adven tahun ini bukan hanya sebagai rutinitas kalender liturgi, tetapi sebagai momentum pertobatan dan pembaruan relasi antar anggota keluarga. Siapkan palungan hati kita agar layak menjadi tempat kelahiran Sang Juruselamat.",
                     style: GoogleFonts.sourceSerif4(
                       fontSize: 18,
                       height: 1.8,
                       color: textWhite
                     ),
                   ),

                   const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          )
        ],
      ),
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 60, width: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: glassBorder)
              ),
              child: IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () {
                   // Share Logic
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link artikel disalin!")));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
