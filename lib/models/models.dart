class Profile {
  final int? id;
  final String name;
  final int age;

  Profile({this.id, required this.name, required this.age});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'age': age};
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(id: map['id'], name: map['name'], age: map['age']);
  }
}

class Medicine {
  final int? id;
  final String name;
  final String dosage;
  final String cause;
  final int tabletsPerDose;        // Number of tablets per dose
  final int timesPerDay;            // How many times per day
  final int totalDays;              // Duration of the course
  final String purpose;             // Purpose/indication
  final String? startDate;          // Start date (YYYY-MM-DD)

  Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.cause,
    this.tabletsPerDose = 1,
    this.timesPerDay = 1,
    this.totalDays = 1,
    this.purpose = '',
    this.startDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'cause': cause,
      'tablets_per_dose': tabletsPerDose,
      'times_per_day': timesPerDay,
      'total_days': totalDays,
      'purpose': purpose,
      'start_date': startDate,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      cause: map['cause'],
      tabletsPerDose: map['tablets_per_dose'] ?? 1,
      timesPerDay: map['times_per_day'] ?? 1,
      totalDays: map['total_days'] ?? 1,
      purpose: map['purpose'] ?? '',
      startDate: map['start_date'],
    );
  }

  /// Total number of doses for this medicine course
  int get totalDoses => timesPerDay * totalDays;
}

class Schedule {
  final int? id;
  final int medicineId;
  final String time; // Format HH:MM
  final int compartment;
  final int isActive; // 0 or 1

  Schedule({
    this.id,
    required this.medicineId,
    required this.time,
    required this.compartment,
    this.isActive = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'time': time,
      'compartment': compartment,
      'is_active': isActive,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'],
      medicineId: map['medicine_id'],
      time: map['time'],
      compartment: map['compartment'],
      isActive: map['is_active'],
    );
  }
}

/// Represents a single dose record (e.g., medicine taken at 9:00 AM on 2025-04-26)
class DoseRecord {
  final int? id;
  final int medicineId;
  final String scheduledDate;      // YYYY-MM-DD
  final String scheduledTime;      // HH:MM
  final String status;             // pending, taken, missed
  final int delayMinutes;          // Minutes late (0 if on time)
  final String? takenTime;         // HH:MM when actually taken
  final bool isManual;             // true if marked manually, false if from sensor

  DoseRecord({
    this.id,
    required this.medicineId,
    required this.scheduledDate,
    required this.scheduledTime,
    this.status = 'pending',
    this.delayMinutes = 0,
    this.takenTime,
    this.isManual = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'status': status,
      'delay_minutes': delayMinutes,
      'taken_time': takenTime,
      'is_manual': isManual ? 1 : 0,
    };
  }

  factory DoseRecord.fromMap(Map<String, dynamic> map) {
    return DoseRecord(
      id: map['id'],
      medicineId: map['medicine_id'],
      scheduledDate: map['scheduled_date'],
      scheduledTime: map['scheduled_time'],
      status: map['status'] ?? 'pending',
      delayMinutes: map['delay_minutes'] ?? 0,
      takenTime: map['taken_time'],
      isManual: (map['is_manual'] ?? 0) == 1,
    );
  }
}

class AdherenceMetrics {
  final int medicineId;
  final int totalDoses;
  final int takenDoses;
  final int missedDoses;
  final int delayMinutes;
  final DateTime? lastUpdated;

  AdherenceMetrics({
    required this.medicineId,
    required this.totalDoses,
    required this.takenDoses,
    required this.missedDoses,
    required this.delayMinutes,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicine_id': medicineId,
      'total_doses': totalDoses,
      'taken_doses': takenDoses,
      'missed_doses': missedDoses,
      'delay_minutes': delayMinutes,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  factory AdherenceMetrics.fromMap(Map<String, dynamic> map) {
    return AdherenceMetrics(
      medicineId: map['medicine_id'],
      totalDoses: map['total_doses'],
      takenDoses: map['taken_doses'],
      missedDoses: map['missed_doses'],
      delayMinutes: map['delay_minutes'],
      lastUpdated: map['last_updated'] != null
          ? DateTime.tryParse(map['last_updated'])
          : null,
    );
  }

  double get adherencePercentage {
    if (totalDoses <= 0) return 0;
    return (takenDoses / totalDoses) * 100;
  }
}
