import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/pages/consilium/chat_screen.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class ConsiliumProfilePage extends StatefulWidget {
  final Map<String, dynamic> counselorData;

  const ConsiliumProfilePage({super.key, required this.counselorData});

  @override
  State<ConsiliumProfilePage> createState() => _ConsiliumProfilePageState();
}

class _ConsiliumProfilePageState extends State<ConsiliumProfilePage> {
  final _supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> _profileFuture;

  // Theme Constants
  static const Color bgDarkPurple = Color(0xFF1E1235);
  static const Color cardPurple = Color(0xFF352453);
  static const Color accentOrange = Color(0xFFFF9F1C);
  static const Color neonGreen = Color(0xFF39FF14);

  // Default Stats Mock
  final Map<String, dynamic> _mockStats = {
    'years': '15 Tahun',
    'helped': '500+',
    'rating': '4.9',
    'specializations': ["Keluarga", "OMK/Remaja", "Iman"],
    'bio': "Melayani dengan hati untuk keluarga muda dan permasalahan remaja. Berpengalaman dalam konseling spiritual Ignasinan.",
    'diocese': "Keuskupan Agung Jakarta",
    'order': "Serikat Jesus (SJ)"
  };

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchCounselorProfile();
  }

  Future<Map<String, dynamic>> _fetchCounselorProfile() async {
    try {
      final String? id = widget.counselorData['id'];
      if (id == null) return widget.counselorData; // Fallback to passed data if no ID

      // Fetch fresh data from profiles table
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, role, avatar_url, last_active, bio, specialization')
          .eq('id', id)
          .single()
          .timeout(const Duration(seconds: 5));

      // Merge with passed data (passed data takes precedence if fetch fails or is null, but here fetch is fresh)
      // Actually, let's merge fresh fetch ON TOP of passed data
      return {...widget.counselorData, ...response};
    } catch (e) {
      debugPrint("Error fetching counselor profile: $e");
      // Fallback: Return passed data directly to show what we have
      return widget.counselorData;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDarkPurple,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          // A. LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accentOrange));
          }

          // B. ERROR / DATA
          final data = snapshot.data ?? widget.counselorData;
          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final String fullName = data['full_name'] ?? 'Romo Anonim';
    final String? avatarUrl = data['avatar_url'];
    final bool isVerified = data['role'] == 'pastor'; // Simple check
    
    // Status Logic
    String status = 'offline';
    if (data['last_active'] != null) {
      final lastActive = DateTime.tryParse(data['last_active'].toString());
      if (lastActive != null && DateTime.now().difference(lastActive).inMinutes < 15) {
        status = 'online';
      }
    }

    // Use fetched bio/spec or fallback to mock
    final String bio = data['bio'] ?? _mockStats['bio'];
    // Handle specialization parsing safely
    List<String> specializations = _mockStats['specializations'];
    if (data['specialization'] != null) {
       // Assuming it might be a comma string or list
       if (data['specialization'] is List) specializations = List<String>.from(data['specialization']);
       else if (data['specialization'] is String) specializations = (data['specialization'] as String).split(',');
    }

    return Stack(
      children: [
        // 1. SCROLLABLE CONTENT
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(fullName, avatarUrl, isVerified, status),
              _buildInfoSection(specializations),
              _buildStatsSection(),
              _buildBioSection(bio),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // 2. BACK BUTTON
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black45,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),

        // 3. STICKY FOOTER
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildStickyFooter(),
        ),
      ],
    );
  }

  Widget _buildHeader(String name, String? avatarUrl, bool isVerified, String status) {
    return SizedBox( // Used SizedBox instead of Container with fixed height
      height: 320,
      child: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: SafeNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              fallbackColor: cardPurple,
              fallbackIcon: Icons.person,
              iconColor: Colors.white24,
            ),
          ),
          // 2. Darken Overlay (Simulating BlendMode.darken)
          Positioned.fill(
            child: Container(color: bgDarkPurple.withOpacity(0.3)),
          ),
          // 3. Gradient & Content
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, bgDarkPurple],
              )
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (avatarUrl == null)
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Colors.blueAccent, size: 24),
                    ]
                  ],
                ),
                
                const SizedBox(height: 8),
                Text(
                  "${_mockStats['order']} | ${_mockStats['diocese']}",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                
                const SizedBox(height: 16),
                _buildStatusBadge(status),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'online':
        color = neonGreen;
        text = "Online & Tersedia";
        icon = Icons.check_circle;
        break;
      case 'busy':
        color = Colors.redAccent;
        text = "Sedang Melayani";
        icon = Icons.do_not_disturb_on;
        break;
      default:
        color = Colors.grey;
        text = "Offline";
        icon = Icons.bedtime;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)
        ]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(List<String> specs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Keahlian", style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specs.map((tag) => Chip(
              backgroundColor: cardPurple,
              label: Text("#$tag"),
              labelStyle: const TextStyle(color: accentOrange, fontWeight: FontWeight.bold),
              side: const BorderSide(color: accentOrange),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardPurple,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(_mockStats['years'], "Imamat"),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem(_mockStats['helped'], "Umat Dibantu"),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem(_mockStats['rating'], "Rating"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildBioSection(String bio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tentang", style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Text(bio, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: bgDarkPurple,
        border: const Border(top: BorderSide(color: Colors.white10)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5))
        ]
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Panggilan Suara segera hadir"))),
              style: ElevatedButton.styleFrom(
                backgroundColor: cardPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
                elevation: 0,
              ),
              child: const Icon(Icons.call, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: () {
                final String? id = widget.counselorData['id'];
                final String name = widget.counselorData['full_name'] ?? 'Konselor';
                final String? avatar = widget.counselorData['avatar_url'];

                if (id != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConsiliumChatScreen(
                        partnerId: id,
                        partnerName: name,
                        partnerAvatar: avatar,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data Konselor tidak valid.")));
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text("KONSULTASI TEKS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
                shadowColor: accentOrange.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
