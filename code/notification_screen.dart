import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/services/supabase_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  late Future<List<Map<String, dynamic>>> _notifFuture;

  @override
  void initState() {
    super.initState();
    _notifFuture = _supabaseService.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Notifikasi", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextTitle)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notifFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifs = snapshot.data ?? [];
          
          if (notifs.isEmpty) {
            return Center(child: Text("Belum ada notifikasi baru.", style: GoogleFonts.outfit(color: kTextMeta)));
          }

          return ListView.separated(
            itemCount: notifs.length,
            separatorBuilder: (ctx, idx) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = notifs[index];
              return _buildNotificationItem(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> item) {
    final type = item['type'];
    final actor = item['actor_name'];
    final time = DateTime.parse(item['created_at']);
    
    IconData icon;
    Color iconColor;
    String text;

    if (type == 'like') {
      icon = Icons.local_fire_department_rounded;
      iconColor = Colors.deepOrange;
      text = "menyalakan api di postingan anda.";
    } else if (type == 'comment') {
      icon = Icons.chat_bubble;
      iconColor = Colors.blue;
      text = "mengomentari postingan anda.";
    } else {
      icon = Icons.person_add;
      iconColor = Colors.green;
      text = "mulai mengikuti anda.";
    }

    return Container(
      color: item['is_read'] ? Colors.white : kPrimary.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(color: kTextTitle, fontSize: 14),
                    children: [
                      TextSpan(text: actor, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: " "),
                      TextSpan(text: text),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(timeago.format(time), style: GoogleFonts.outfit(color: kTextMeta, fontSize: 12)),
              ],
            ),
          ),
          
          // Optional: Thumbnail for post interactions
          if (type == 'like' || type == 'comment')
            Container(
              margin: const EdgeInsets.only(left: 8),
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
              child: const Icon(Icons.image, color: Colors.grey, size: 20),
            )
        ],
      ),
    );
  }
}
