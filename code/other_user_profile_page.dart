import 'package:flutter/material.dart';
import 'package:mychatolic_app/chat_detail_page.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class OtherUserProfilePage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const OtherUserProfilePage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    // Extract Data safely
    final String name = userData['name'] ?? 'Umat';
    final int age = userData['age'] ?? 0;
    final String parish = userData['parish'] ?? 'Paroki';
    final String? avatar = userData['avatar']; // null implies default
    
    // Theme Colors
    const Color bgDarkPurple = Color(0xFF1E1235);
    const Color cardPurple = Color(0xFF352453);
    const Color accentOrange = Color(0xFFFF9F1C);
    
    return Scaffold(
      backgroundColor: bgDarkPurple,
      appBar: AppBar(
        title: const Text("Profil Teman", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. Info Card
            Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardPurple,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                ]
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    padding: const EdgeInsets.all(4),
                     decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Colors.grey, Colors.white24]),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: bgDarkPurple,
                      child: SafeNetworkImage(
                        imageUrl: avatar,
                        width: 100, height: 100,
                        borderRadius: BorderRadius.circular(50),
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.person,
                        iconColor: Colors.white,
                        fallbackColor: bgDarkPurple,
                        fallbackWidget: avatar == null 
                          ? Center(child: Text(name.isNotEmpty ? name[0] : "?", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)))
                          : null,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Name & Age
                  Text(
                    "$name, $age", 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 8),
                  
                  // Parish / Role
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: Text(parish, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 32),

                  // Action Button: CHAT only (No Follow/Feed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                         int dummyId = 999;
                         Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(chatId: dummyId, name: name)));
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, color: Colors.black),
                      label: const Text("KIRIM PESAN"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentOrange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            // No Feed/Stats here, strictly info.
            const Text(
              "Profil ini hanya menampilkan informasi dasar.",
              style: TextStyle(color: Colors.white24, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }
}
