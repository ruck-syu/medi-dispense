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

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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
        cause TEXT NOT NULL,
        tablets_per_dose INTEGER NOT NULL DEFAULT 1,
        times_per_day INTEGER NOT NULL DEFAULT 1,
        total_days INTEGER NOT NULL DEFAULT 1,
        purpose TEXT NOT NULL DEFAULT '',
        start_date TEXT
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

    await db.execute('''
      CREATE TABLE dose_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        scheduled_date TEXT NOT NULL,
        scheduled_time TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        delay_minutes INTEGER NOT NULL DEFAULT 0,
        taken_time TEXT,
        is_manual INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE,
        UNIQUE(medicine_id, scheduled_date, scheduled_time)
      )
    ''');

    await db.execute('''
      CREATE TABLE adherence_metrics (
        medicine_id INTEGER PRIMARY KEY,
        total_doses INTEGER NOT NULL DEFAULT 0,
        taken_doses INTEGER NOT NULL DEFAULT 0,
        missed_doses INTEGER NOT NULL DEFAULT 0,
        delay_minutes INTEGER NOT NULL DEFAULT 0,
        last_updated TEXT,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS adherence_metrics (
          medicine_id INTEGER PRIMARY KEY,
          total_doses INTEGER NOT NULL DEFAULT 0,
          taken_doses INTEGER NOT NULL DEFAULT 0,
          missed_doses INTEGER NOT NULL DEFAULT 0,
          delay_minutes INTEGER NOT NULL DEFAULT 0,
          last_updated TEXT,
          FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add new columns to medicines table
      await db.execute('ALTER TABLE medicines ADD COLUMN tablets_per_dose INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE medicines ADD COLUMN times_per_day INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE medicines ADD COLUMN total_days INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE medicines ADD COLUMN purpose TEXT NOT NULL DEFAULT \'\'');
      await db.execute('ALTER TABLE medicines ADD COLUMN start_date TEXT');

      // Create dose_records table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dose_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicine_id INTEGER NOT NULL,
          scheduled_date TEXT NOT NULL,
          scheduled_time TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          delay_minutes INTEGER NOT NULL DEFAULT 0,
          taken_time TEXT,
          is_manual INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE,
          UNIQUE(medicine_id, scheduled_date, scheduled_time)
        )
      ''');
    }
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

  Future<Medicine?> getMedicineById(int medicineId) async {
    final db = await instance.database;
    final result = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicineId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Medicine.fromMap(result.first);
  }

  Future<Medicine> addMedicine(Medicine medicine) async {
    final db = await instance.database;
    final id = await db.insert('medicines', medicine.toMap());
    return Medicine(
      id: id,
      name: medicine.name,
      dosage: medicine.dosage,
      cause: medicine.cause,
      tabletsPerDose: medicine.tabletsPerDose,
      timesPerDay: medicine.timesPerDay,
      totalDays: medicine.totalDays,
      purpose: medicine.purpose,
      startDate: medicine.startDate,
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

  Future<AdherenceMetrics?> getAdherenceMetrics(int medicineId) async {
    final db = await instance.database;
    final maps = await db.query(
      'adherence_metrics',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AdherenceMetrics.fromMap(maps.first);
  }

  Future<void> upsertAdherenceMetrics(AdherenceMetrics metrics) async {
    final db = await instance.database;
    await db.insert(
      'adherence_metrics',
      metrics.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Dose Record operations
  /// Get all dose records for a specific medicine
  Future<List<DoseRecord>> getDoseRecords(int medicineId) async {
    final db = await instance.database;
    final result = await db.query(
      'dose_records',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
      orderBy: 'scheduled_date DESC, scheduled_time DESC',
    );
    return result.map((json) => DoseRecord.fromMap(json)).toList();
  }

  /// Get dose records for a specific date
  Future<List<DoseRecord>> getDoseRecordsForDate(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'dose_records',
      where: 'scheduled_date = ?',
      whereArgs: [date],
      orderBy: 'scheduled_time ASC',
    );
    return result.map((json) => DoseRecord.fromMap(json)).toList();
  }

  /// Get all pending doses from now onward.
  Future<List<DoseRecord>> getPendingDoseRecordsFromNow() async {
    final db = await instance.database;
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      '''
      SELECT *
      FROM dose_records
      WHERE status = 'pending'
        AND (scheduled_date > ? OR (scheduled_date = ? AND scheduled_time >= ?))
      ORDER BY scheduled_date ASC, scheduled_time ASC
      ''',
      [dateStr, dateStr, timeStr],
    );

    return result.map((json) => DoseRecord.fromMap(json)).toList();
  }

  /// Get pending doses that should trigger now.
  Future<List<DoseRecord>> getPendingDosesDueAtOrBefore(
    String date,
    String time,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'dose_records',
      where: 'status = ? AND scheduled_date = ? AND scheduled_time <= ?',
      whereArgs: ['pending', date, time],
      orderBy: 'scheduled_time ASC',
    );
    return result.map((json) => DoseRecord.fromMap(json)).toList();
  }

  /// Get dose records for a medicine on a specific date
  Future<List<DoseRecord>> getDoseRecordsForMedicineAndDate(
    int medicineId,
    String date,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'dose_records',
      where: 'medicine_id = ? AND scheduled_date = ?',
      whereArgs: [medicineId, date],
      orderBy: 'scheduled_time ASC',
    );
    return result.map((json) => DoseRecord.fromMap(json)).toList();
  }

  /// Insert or update a dose record
  Future<int> upsertDoseRecord(DoseRecord record) async {
    final db = await instance.database;
    return await db.insert(
      'dose_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mark a dose as taken
  Future<int> markDoseAsTaken(
    int medicineId,
    String scheduledDate,
    String scheduledTime,
    int delayMinutes,
    String takenTime,
  ) async {
    final db = await instance.database;
    return await db.update(
      'dose_records',
      {
        'status': 'taken',
        'delay_minutes': delayMinutes,
        'taken_time': takenTime,
        'is_manual': 1,
      },
      where: 'medicine_id = ? AND scheduled_date = ? AND scheduled_time = ?',
      whereArgs: [medicineId, scheduledDate, scheduledTime],
    );
  }

  /// Mark a dose as missed
  Future<int> markDoseAsMissed(
    int medicineId,
    String scheduledDate,
    String scheduledTime,
  ) async {
    final db = await instance.database;
    return await db.update(
      'dose_records',
      {'status': 'missed'},
      where: 'medicine_id = ? AND scheduled_date = ? AND scheduled_time = ?',
      whereArgs: [medicineId, scheduledDate, scheduledTime],
    );
  }

  /// Generate dose records for a medicine based on its schedule
  Future<void> generateDoseRecords(Medicine medicine) async {
    final db = await instance.database;
    
    // Get the scheduled times for this medicine
    final schedules = await db.query(
      'schedules',
      where: 'medicine_id = ? AND is_active = 1',
      whereArgs: [medicine.id],
    );

    if (schedules.isEmpty) return;

    final startDate = medicine.startDate != null
        ? DateTime.parse(medicine.startDate!)
        : DateTime.now();

    // Generate dose records for each day and each scheduled time
    for (int day = 0; day < medicine.totalDays; day++) {
      final currentDate = startDate.add(Duration(days: day));
      final dateStr =
          '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

      for (final schedule in schedules) {
        final timeStr = schedule['time'] as String;
        
        final doseRecord = DoseRecord(
          medicineId: medicine.id!,
          scheduledDate: dateStr,
          scheduledTime: timeStr,
          status: 'pending',
        );

        await db.insert(
          'dose_records',
          doseRecord.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore, // Don't overwrite existing
        );
      }
    }
  }

  /// Get dose summary stats for a medicine
  Future<Map<String, int>> getDoseSummary(int medicineId) async {
    final db = await instance.database;
    
    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'taken' THEN 1 ELSE 0 END) as taken,
        SUM(CASE WHEN status = 'missed' THEN 1 ELSE 0 END) as missed,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending
      FROM dose_records
      WHERE medicine_id = ?
      ''',
      [medicineId],
    );

    if (result.isEmpty) {
      return {'total': 0, 'taken': 0, 'missed': 0, 'pending': 0};
    }

    final row = result.first;
    return {
      'total': (row['total'] as int?) ?? 0,
      'taken': (row['taken'] as int?) ?? 0,
      'missed': (row['missed'] as int?) ?? 0,
      'pending': (row['pending'] as int?) ?? 0,
    };
  }
}
