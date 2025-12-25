class Schedule {
  final String id; // UUID
  final String churchId;
  final int dayOfWeek; // 0=Minggu, 1=Senin...
  final String timeStart; // "HH:MM:SS"
  final String? language;
  final String? label; 

  Schedule({
    required this.id,
    required this.churchId,
    required this.dayOfWeek,
    required this.timeStart,
    this.language,
    this.label,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    try {
      return Schedule(
        // Defensive: Handle nulls and convert to String safely
        id: (json['id'] ?? '').toString(),
        churchId: (json['church_id'] ?? '').toString(),
        
        // Defensive: Try parse int, handle String '1' or int 1, default 0
        dayOfWeek: int.tryParse((json['day_of_week'] ?? 0).toString()) ?? 0,
        
        timeStart: (json['time_start'] ?? '00:00').toString(),
        
        // Defensive: Ensure null becomes empty string if preferred, or keep null support
        // User requested strict null safety:
        language: (json['language'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
      );
    } catch (e, stack) {
      // Debug Logging
      print('CRITICAL ERROR Parsing Schedule: $e');
      print('Stack: $stack');
      print('Problematic JSON: $json');
      
      // Return Dummy/Safe Object to prevent Red Screen
      return Schedule(
        id: '', 
        churchId: '', 
        dayOfWeek: 0, 
        timeStart: 'Error',
        language: 'Data Error',
        label: 'Please Report',
      );
    }
  }

  // Getter for Display
  String get dayName {
     const days = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
     if (dayOfWeek >= 0 && dayOfWeek < days.length) return days[dayOfWeek];
     return "Minggu";
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'church_id': churchId,
      'day_of_week': dayOfWeek,
      'time_start': timeStart,
      'language': language,
      'label': label,
    };
  }
}
