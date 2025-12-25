import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Pages
import 'package:mychatolic_app/pages/home_screen.dart'; 
import 'package:mychatolic_app/pages/create_post_screen.dart'; // NEW
import 'package:mychatolic_app/pages/church_list_page.dart'; 
import 'package:mychatolic_app/pages/consilium/consilium_page.dart';
import 'package:mychatolic_app/pages/profile_page.dart';
import 'package:mychatolic_app/pages/radar_page.dart';
import 'package:mychatolic_app/core/app_colors.dart';
import 'package:mychatolic_app/pages/social_inbox_page.dart';

// Placeholder for Chat (since Consilium handles real chat, this might be a generic inbox later)
class ChatPlaceholderPage extends StatelessWidget {
  const ChatPlaceholderPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Chat Coming Soon", style: TextStyle(color: Colors.grey))),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;

  // GlobalKey to access HomeScreen state from here
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  Key _profilePageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _updateLastActive();
    _checkUserProfile();
  }

  void _checkUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      // Logic preserved
      final profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (profile == null) {
        // Handle missing profile if needed
      }
    }
  }

  Future<void> _updateLastActive() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').update({
          'last_active': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      } catch (e) {
        debugPrint("Error updating last active: $e");
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic children list
    final List<Widget> children = [
      HomeScreen(key: _homeScreenKey), // Use GlobalKey
      const ChurchListPage(),    
      const RadarPage(),        
      const ConsiliumPage(),    
      const SocialInboxPage(),  
      ProfilePage(key: _profilePageKey),       
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      body: IndexedStack(
        index: _currentIndex,
        children: children,
      ),
      // FAB ONLY ON HOME TAB
      floatingActionButton: _currentIndex == 0 
          ? FloatingActionButton(
              onPressed: () async {
                 final result = await Navigator.push(
                   context, 
                   MaterialPageRoute(builder: (_) => const CreatePostScreen())
                 );
                 
                 // Refresh Home nicely without flickering
                 if (result == true) {
                   _homeScreenKey.currentState?.refreshPosts(); // Call public method
                   setState(() {
                     _currentIndex = 0;
                     _profilePageKey = UniqueKey(); // Keep Profile refresh as is
                   });
                 }
              },
              backgroundColor: const Color(0xFF0088CC), 
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).cardColor, 
          boxShadow: [
             BoxShadow(
               color: Theme.of(context).shadowColor.withOpacity(0.1), 
               blurRadius: 10, 
               offset: const Offset(0, -4) 
             )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          elevation: 0,
          selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), // Reduced size slightly for 6 items
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: "Jadwal",
            ),
            // NEW RADAR ITEM
            BottomNavigationBarItem(
              icon: Icon(Icons.radar), 
              label: "Radar",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.spa),
              label: "Consilium",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble), 
              label: "Chat",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Profil",
            ),
          ],
        ),
      ),
    );
  }
}

