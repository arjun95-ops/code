class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? role;
  final String? bio;
  final String? verificationStatus;

  // Location (Text)
  final String? country;
  final String? diocese;
  final String? parish;

  // Demographics
  final DateTime? birthDate;
  final String? ethnicity;
  
  // Privacy (Mapped from is_age_visible, is_ethnicity_visible)
  final bool showAge;
  final bool showEthnicity;

  Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.role,
    this.bio,
    this.verificationStatus,
    this.country,
    this.diocese,
    this.parish,
    this.birthDate,
    this.ethnicity,
    this.showAge = false,
    this.showEthnicity = false,
  });

  // Safe Getter for UI
  bool get isVerified => verificationStatus?.toLowerCase() == 'approved';

  // Age Getter (Safe Calc)
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int val = now.year - birthDate!.year;
    if (now.month < birthDate!.month || (now.month == birthDate!.month && now.day < birthDate!.day)) {
      val--;
    }
    return val;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      // Anti-Crash: Use .toString() ?? ''
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString(),
      bio: json['bio']?.toString(),
      verificationStatus: json['verification_status']?.toString(),
      
      // Location (Text)
      country: json['country']?.toString(),
      diocese: json['diocese']?.toString(),
      parish: json['parish']?.toString(),

      // Demographics
      ethnicity: json['ethnicity']?.toString(),
      birthDate: json['birth_date'] != null 
          ? DateTime.tryParse(json['birth_date'].toString()) 
          : null,
      
      // Privacy (Boolean Columns)
      showAge: json['is_age_visible'] == true, 
      showEthnicity: json['is_ethnicity_visible'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'role': role,
      'bio': bio,
      'verification_status': verificationStatus,
      'country': country,
      'diocese': diocese,
      'parish': parish,
      'birth_date': birthDate != null 
          ? "${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}"
          : null,
      'ethnicity': ethnicity,
      'is_age_visible': showAge,
      'is_ethnicity_visible': showEthnicity,
    };
  }
}
