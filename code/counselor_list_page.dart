import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class CounselorListPage extends StatefulWidget {
  const CounselorListPage({super.key});

  @override
  State<CounselorListPage> createState() => _CounselorListPageState();
}

class _CounselorListPageState extends State<CounselorListPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Updated length to 5: SEMUA, PASTOR, SUSTER, BRUDER, KATEKIS
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepViolet,
      appBar: AppBar(
        title: const Text("Daftar Konselor", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Added isScrollable to support many tabs
          labelColor: AppTheme.vibrantOrange,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppTheme.vibrantOrange,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "SEMUA"),
            Tab(text: "PASTOR"),
            Tab(text: "SUSTER"),
            Tab(text: "BRUDER"),
            Tab(text: "KATEKIS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(null),      // All
          _buildList('Pastor'),  // Filter 'Pastor'
          _buildList('Suster'),  // Filter 'Suster'
          _buildList('Bruder'),  // Filter 'Bruder'
          _buildList('Katekis'), // Filter 'Katekis'
        ],
      ),
    );
  }

  Widget _buildList(String? roleFilter) {
    var query = _supabase.from('profiles').select().neq('user_category', 'Umat Umum'); // Default assumption: all displayed here are not Umat

    if (roleFilter != null) {
      query = query.eq('user_category', roleFilter);
    } else {
      // For "All", we want all service roles
      query = query.inFilter('user_category', ['Pastor', 'Suster', 'Bruder', 'Katekis']);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: query.asStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.vibrantOrange));

        final data = snapshot.data!;

        if (data.isEmpty) {
          return const Center(child: Text("Belum ada konselor.", style: TextStyle(color: Colors.white54)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: data.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final user = data[index];
            final avatar = user['avatar_url'];
            final name = user['full_name'] ?? "Tanpa Nama";
            // Display 'user_category' as role label for consistency with filter
            final role = user['user_category']?.toString().toUpperCase() ?? "UNKNOWN";

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.glassyViolet,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                   Container(
                     width: 60, height: 60,
                     decoration: const BoxDecoration(shape: BoxShape.circle),
                     child: SafeNetworkImage(
                       imageUrl: avatar,
                       width: 60, height: 60,
                       borderRadius: BorderRadius.circular(30),
                       fit: BoxFit.cover,
                       fallbackIcon: Icons.person,
                       iconColor: Colors.white54,
                       fallbackColor: AppTheme.darkInputFill,
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                         const SizedBox(height: 4),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                           decoration: BoxDecoration(
                             color: AppTheme.vibrantOrange.withOpacity(0.2), 
                             borderRadius: BorderRadius.circular(4),
                             border: Border.all(color: AppTheme.vibrantOrange),
                           ),
                           child: Text(role, style: const TextStyle(color: AppTheme.vibrantOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                         )
                       ],
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                     onPressed: () {
                       // Logic to start chat directly (Optional, or integrate with ChatPage if needed)
                     },
                   )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
