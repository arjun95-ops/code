import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:mychatolic_app/core/theme.dart';

class ChatPage extends StatefulWidget {
  final int requestId; // The Consultation ID
  final String topic;
  final bool isPastoral; // True if with Romo/Suster (Pastoral), False if Peer/General

  const ChatPage({
    super.key, 
    required this.requestId, 
    required this.topic, 
    required this.isPastoral
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- DESIGN SYSTEM CONSTANTS (White UI) ---




  
  static const Color kBubbleIncoming = Color(0xFFF1F5F9); // Slate 100
  static const Color kBorder = Color(0xFFE2E8F0); // Slate 200
  
  static const Color kTextTitle = Color(0xFF0F172A);
  static const Color kTextBody = Color(0xFF334155);
  static const Color kTextMeta = Color(0xFF64748B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [kSecondary, kPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubbleGradient = LinearGradient(
    colors: [kSecondary, kPrimary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Messages State
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
  }

  Future<void> _fetchMessages() async {
    // In a real implementation, we would query 'consilium_messages' table joined with profiles.
    // For now, we simulate initial load or use dummy if table not ready.
    // If 'consilium_messages' exists, use it. IF NOT, we simulate.
    
    // CHECKPOINT: Simulating fetch for correct UI demonstration
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _messages = [
          {
            'text': 'Halo, saya ingin berkonsultasi mengenai ${widget.topic}.',
            'isMe': true,
            'time': '10:00',
            'sender': 'Saya'
          },
          {
            'text': 'Selamat pagi. Baik, silakan ceritakan lebih lanjut.',
            'isMe': false,
            'time': '10:05',
            'sender': widget.isPastoral ? 'Konselor Pastoral' : 'Konselor Teman'
          }
        ];
        _isLoading = false;
      });
    }
  }

  void _subscribeToMessages() {
    // Realtime subscription logic would go here
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        'sender': 'Saya'
      });
      _messageController.clear();
    });

    // TODO: Insert into Supabase table 'consilium_messages'
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              // Info Banner (Consultation Specific)
              _buildTopicBanner(),
              
              // Chat List
              Expanded(
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: kPrimary))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Bottom padding
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
              ),
            ],
          ),

          // Floating Input
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildInputBar(),
          )
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kBackground.withValues(alpha: 0.8),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: kTextBody),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isPastoral ? "Konseling Pastoral" : "Teman Bicara",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text("Sesi Aktif", style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 12)),
            ],
          )
        ],
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
          onPressed: () {}, // Show Session Details
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kBorder, height: 1),
      ),
    );
  }

  Widget _buildTopicBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kBackground,
        border: Border(bottom: BorderSide(color: kBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
        ]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)
            ),
            child: const Icon(Icons.topic_rounded, color: kPrimary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Topik Diskusi", style: GoogleFonts.outfit(color: kTextMeta, fontSize: 10)),
                Text(widget.topic, style: GoogleFonts.outfit(color: kTextTitle, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['isMe'] as bool;
    final String sender = msg['sender'] ?? "User";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender Name (if not me)
            if (!isMe)
              Padding(
                 padding: const EdgeInsets.only(left: 4, bottom: 4),
                 child: Text(sender, style: GoogleFonts.outfit(color: kTextMeta, fontSize: 10)),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe ? bubbleGradient : null,
                color: isMe ? null : kBubbleIncoming,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                ),
                border: isMe ? null : Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg['text'] ?? "", 
                    style: GoogleFonts.outfit(
                      color: isMe ? Colors.white : kTextTitle, 
                      fontSize: 15, 
                      height: 1.4
                    )
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      msg['time'] ?? "", 
                      style: GoogleFonts.outfit(color: isMe ? Colors.white70 : kTextMeta, fontSize: 10)
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
     return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(30), 
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add_circle_outline, color: kTextMeta),
                tooltip: "Lampirkan",
              ),
              
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.outfit(color: kTextTitle),
                  minLines: 1,
                  maxLines: 4,
                  cursorColor: kPrimary,
                  decoration: InputDecoration(
                    hintText: "Tulis pesan...",
                    hintStyle: GoogleFonts.outfit(color: kTextMeta),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
