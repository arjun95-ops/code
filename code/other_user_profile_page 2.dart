import 'package:flutter/material.dart';
import 'package:mychatolic_app/pages/profile_page.dart';

class OtherUserProfilePage extends StatelessWidget {
  final String userId;

  const OtherUserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Reuse the existing ProfilePage which already handles:
    // - Fetching data by userId
    // - "Back" button logic (isBackButtonEnabled)
    // - Follow vs Edit button logic (via _isMe check inside ProfilePage)
    return ProfilePage(
      userId: userId,
      isBackButtonEnabled: true,
    );
  }
}
