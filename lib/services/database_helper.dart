import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medidispense.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        cause TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        time TEXT NOT NULL,
        compartment INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
  }

  // Profile operations
  Future<Profile?> getProfile() async {
    final db = await instance.database;
    final maps = await db.query('profile', limit: 1);
    if (maps.isNotEmpty) {
      return Profile.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<void> saveProfile(Profile profile) async {
    final db = await instance.database;
    final existing = await getProfile();
    if (existing != null) {
      await db.update(
        'profile',
        profile.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await db.insert('profile', profile.toMap());
    }
  }

  // Medicine operations
  Future<List<Medicine>> getMedicines() async {
    final db = await instance.database;
    final result = await db.query('medicines');
    return result.map((json) => Medicine.fromMap(json)).toList();
  }

  Future<Medicine> addMedicine(Medicine medicine) async {
    final db = await instance.database;
    final id = await db.insert('medicines', medicine.toMap());
    return Medicine(
      id: id,
      name: medicine.name,
      dosage: medicine.dosage,
      cause: medicine.cause,
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await instance.database;
    // Schedules linked via FK will be handled by CASCADE if enabled, but let's be safe
    await db.delete('schedules', where: 'medicine_id = ?', whereArgs: [id]);
    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // Schedule operations
  Future<List<Schedule>> getSchedules() async {
    final db = await instance.database;
    final result = await db.query('schedules', orderBy: 'time ASC');
    return result.map((json) => Schedule.fromMap(json)).toList();
  }

  Future<Schedule> addSchedule(Schedule schedule) async {
    final db = await instance.database;
    final id = await db.insert('schedules', schedule.toMap());
    return Schedule(
      id: id,
      medicineId: schedule.medicineId,
      time: schedule.time,
      compartment: schedule.compartment,
      isActive: schedule.isActive,
    );
  }

  Future<int> updateSchedule(Schedule schedule) async {
    final db = await instance.database;
    return db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> deleteSchedule(int id) async {
    final db = await instance.database;
    return await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }
}
