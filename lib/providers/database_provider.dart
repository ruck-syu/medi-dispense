import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_helper.dart';

class DatabaseProvider extends ChangeNotifier {
  Profile? profile;
  List<Medicine> medicines = [];
  List<Schedule> schedules = [];

  DatabaseProvider() {
    loadData();
  }

  Future<void> loadData() async {
    profile = await DatabaseHelper.instance.getProfile();
    medicines = await DatabaseHelper.instance.getMedicines();
    schedules = await DatabaseHelper.instance.getSchedules();
    notifyListeners();
  }

  Future<void> saveProfile(String name, int age) async {
    final newProfile = Profile(id: profile?.id, name: name, age: age);
    await DatabaseHelper.instance.saveProfile(newProfile);
    profile = newProfile;
    notifyListeners();
  }

  Future<Medicine> addMedicine(Medicine medicine) async {
    final savedMed = await DatabaseHelper.instance.addMedicine(medicine);
    medicines.add(savedMed);
    notifyListeners();
    return savedMed;
  }

  Future<void> deleteMedicine(int id) async {
    await DatabaseHelper.instance.deleteMedicine(id);
    medicines.removeWhere((m) => m.id == id);
    schedules.removeWhere((s) => s.medicineId == id);
    notifyListeners();
  }

  Future<void> addSchedule(int medicineId, String time, int compartment) async {
    final schedule = Schedule(
      medicineId: medicineId,
      time: time,
      compartment: compartment,
    );
    final saved = await DatabaseHelper.instance.addSchedule(schedule);
    schedules.add(saved);
    schedules.sort((a, b) => a.time.compareTo(b.time));
    notifyListeners();
  }

  Future<void> toggleSchedule(Schedule schedule) async {
    final updated = Schedule(
      id: schedule.id,
      medicineId: schedule.medicineId,
      time: schedule.time,
      compartment: schedule.compartment,
      isActive: schedule.isActive == 1 ? 0 : 1,
    );
    await DatabaseHelper.instance.updateSchedule(updated);
    final index = schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      schedules[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(int id) async {
    await DatabaseHelper.instance.deleteSchedule(id);
    schedules.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Medicine? getMedicineById(int id) {
    try {
      return medicines.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }
}
