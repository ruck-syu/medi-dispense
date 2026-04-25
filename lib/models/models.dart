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

  Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.cause,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'dosage': dosage, 'cause': cause};
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      cause: map['cause'],
    );
  }
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
