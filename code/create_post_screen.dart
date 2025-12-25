import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/services/supabase_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _contentController = TextEditingController();
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  bool _isSending = false;
  
  // Location Stubs (In real app, fetch from user profile)
  String? _countryId; 
  String? _dioceseId;
  String? _churchId;

  @override
  void initState() {
    super.initState();
    _fetchUserDefaultLocation();
  }

  void _fetchUserDefaultLocation() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
       try {
          final data = await Supabase.instance.client
              .from('profiles')
              .select('country_id, diocese_id, church_id')
              .eq('id', user.id)
              .maybeSingle();
          if (data != null && mounted) {
             setState(() {
               // Safe parsing for UUIDs
               _countryId = data['country_id']?.toString();
               _dioceseId = data['diocese_id']?.toString();
               _churchId = data['church_id']?.toString();
             });
          }
       } catch (e) {
         // ignore
       }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil gambar")));
    }
  }

  Future<void> _sendPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imageFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tulis sesuatu atau pilih gambar")));
       return;
    }

    setState(() => _isSending = true);

    try {
      String? imageUrl;
      
      // 1. Upload Image First
      if (_imageFile != null) {
         imageUrl = await _supabaseService.uploadPostImage(_imageFile!);
      }

      // 2. Create Post
      await _supabaseService.createPost(
        content: content,
        imageUrl: imageUrl, // Pass URL, not file
        type: _imageFile != null ? 'photo' : 'text',
        countryId: _countryId,
        dioceseId: _dioceseId,
        churchId: _churchId,
      );

      if (mounted) {
         Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim: $e")));
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Buat Postingan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextTitle)),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: kTextTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: _isSending 
                   ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                   : Text("Kirim", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
         padding: const EdgeInsets.all(20),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // User Header Info (Optional, but nice)
             
             // Input Field
             TextField(
               controller: _contentController,
               maxLines: 5,
               autofocus: true,
               decoration: InputDecoration(
                 hintText: "Apa yang anda pikirkan?",
                 hintStyle: GoogleFonts.outfit(color: kTextMeta, fontSize: 18),
                 border: InputBorder.none,
               ),
               style: GoogleFonts.outfit(fontSize: 18, color: kTextTitle),
             ),
             
             const SizedBox(height: 20),
             
             // Image Preview
             if (_imageFile != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _imageFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    )
                  ],
                ),
           ],
         ),
      ),
      // Sticky Bottom Bar for Actions
      bottomNavigationBar: Container(
         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
         decoration: BoxDecoration(
           color: Colors.white,
           border: Border(top: BorderSide(color: Colors.grey[200]!)),
         ),
         child: SafeArea(
           child: Row(
             children: [
               Text("Tambahkan ke postingan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextTitle)),
               const Spacer(),
               IconButton(
                 onPressed: _pickImage,
                 icon: const Icon(Icons.image_outlined, color: kPrimary, size: 28),
               ),
               // Add more like camera, tag, etc if needed
             ],
           ),
         ),
      ),
    );
  }
}
