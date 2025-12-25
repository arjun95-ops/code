import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

// Menggunakan Tema Baru: White & Gradient
class ConsiliumChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;

  const ConsiliumChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
  });

  @override
  State<ConsiliumChatScreen> createState() => _ConsiliumChatScreenState();
}

class _ConsiliumChatScreenState extends State<ConsiliumChatScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final TextEditingController _textController = TextEditingController();
  
  String? _chatId; // ID Percakapan (request_id di tabel consilium_requests)
  bool _isLoading = true;

  // Animation controller for generic shake (visual cue placeholder)
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _initializeChatSession();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // Cari atau Buat Sesi Chat (Match logic Firebase 'chats/{id}')
  Future<void> _initializeChatSession() async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      // 1. Cek apakah sudah ada sesi dengan partner ini?
      final res = await _supabase.from('consilium_requests')
          .select('id')
          .or('and(user_id.eq.$myId,partner_id.eq.${widget.partnerId}),and(user_id.eq.${widget.partnerId},partner_id.eq.$myId)')
          .limit(1)
          .maybeSingle();

      if (res != null) {
        setState(() {
          _chatId = res['id']; // Gunakan ID existing
          _isLoading = false;
        });
      } else {
        // 2. Jika belum ada, Buat Sesi Baru
        final newSession = await _supabase.from('consilium_requests').insert({
          'user_id': myId,
          'partner_id': widget.partnerId,
          'topic': 'Konsultasi Umum', // Default topic
          'status': 'open',
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();

        setState(() {
          _chatId = newSession['id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error init chat: $e");
      setState(() => _isLoading = false);
    }
  }

  void _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _chatId == null) return;

    _textController.clear();

    try {
      await _supabase.from('consilium_messages').insert({
        'request_id': _chatId,
        'sender_id': _supabase.auth.currentUser!.id,
        'content': content,
        'type': 'text', // Standard type
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengirim.")));
      }
    }
  }

  void _sendBeeb() async {
    if (_chatId == null) return;
    
    // Trigger visual feedback locally
    _shakeController.forward(from: 0);

    try {
      await _supabase.from('consilium_messages').insert({
        'request_id': _chatId,
        'sender_id': _supabase.auth.currentUser!.id,
        'content': "BEEB!",
        'type': 'beeb', // Special Type
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Failed to send Beeb: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final bodyColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final dividerColor = theme.dividerColor;
    final inputFillColor = theme.brightness == Brightness.dark ? Colors.grey[800]! : const Color(0xFFF9FAFB);
    final partnerBubbleColor = theme.brightness == Brightness.dark ? Colors.grey[800]! : const Color(0xFFF1F5F9);

    // Local Signature Constant
    const kSignatureGradient = LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: backgroundColor, 
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: titleColor, 
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: SafeNetworkImage(
                imageUrl: widget.partnerAvatar,
                width: 32, height: 32,
                borderRadius: BorderRadius.circular(16),
                fit: BoxFit.cover,
                fallbackIcon: Icons.person,
                iconColor: metaColor,
                fallbackColor: partnerBubbleColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.partnerName, style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text("Online", style: TextStyle(color: Colors.green, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: dividerColor, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // MESSAGES AREA
          Expanded(
            child: _chatId == null 
              ? (_isLoading 
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : Center(child: Text("Gagal memuat sesi.", style: TextStyle(color: metaColor))))
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('consilium_messages')
                      .stream(primaryKey: ['id'])
                      .eq('request_id', _chatId!)
                      .order('created_at', ascending: true),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: bodyColor)));
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: primaryColor));

                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return Center(
                        child: Text("Mulai konsultasi dengan ${widget.partnerName}...", 
                        style: TextStyle(color: metaColor)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg['sender_id'] == _supabase.auth.currentUser?.id;
                        final type = msg['type'] as String? ?? 'text'; // Handle missing type

                        return _buildChatBubble(msg['content'] ?? '', isMe, msg['created_at'], type, theme, kSignatureGradient, partnerBubbleColor, titleColor, metaColor);
                      },
                    );
                  },
                ),
          ),

          // INPUT AREA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: dividerColor)),
            ),
            child: Row(
              children: [
                // BEEB BUTTON
                IconButton(
                  icon: Icon(Icons.notifications_active_rounded, color: primaryColor),
                  tooltip: "Kirim Beeb!",
                  onPressed: _sendBeeb,
                ),
                const SizedBox(width: 4),
                
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(color: bodyColor),
                    decoration: InputDecoration(
                      hintText: "Ketik pesan...",
                      hintStyle: TextStyle(color: metaColor),
                      filled: true,
                      fillColor: inputFillColor, 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: kSignatureGradient, // Submit Button Gradient
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatBubble(String content, bool isMe, String createdAt, String type, ThemeData theme, Gradient gradient, Color partnerColor, Color titleColor, Color metaColor) {
    // SPECIAL UI FOR BEEB
    if (type == 'beeb') {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1), 
            border: Border.all(color: Colors.red, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "BEEB!",
                style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                timeago.format(DateTime.parse(createdAt), locale: 'en_short'),
                style: const TextStyle(fontSize: 10, color: Colors.redAccent),
              )
            ],
          ),
        ),
      );
    }

    // STANDARD BUBBLE
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          // Gradient for Me, Light Gray for Partner
          gradient: isMe ? gradient : null, 
          color: isMe ? null : partnerColor, 
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isMe ? Colors.white : titleColor, // White on Gradient, Dark on Gray
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeago.format(DateTime.parse(createdAt), locale: 'en_short'),
              style: TextStyle(
                fontSize: 10, 
                color: isMe ? Colors.white70 : metaColor,
              ),
            )
          ],
        ),
      ),
    );
  }
}
