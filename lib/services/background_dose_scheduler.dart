import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'database_helper.dart';
import 'local_ai_service.dart';
import 'risk_inference_service.dart';

class BackgroundDoseScheduler {
  BackgroundDoseScheduler._();

  static final BackgroundDoseScheduler instance = BackgroundDoseScheduler._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await AndroidAlarmManager.initialize();
    _initialized = true;
  }

  Future<void> scheduleAllPendingDoseAlarms() async {
    await initialize();

    final pending = await DatabaseHelper.instance
        .getPendingDoseRecordsFromNow();
    for (final dose in pending) {
      await _scheduleDoseAlarm(dose);
    }
  }

  Future<void> _scheduleDoseAlarm(DoseRecord dose) async {
    final trigger = DateTime.tryParse(
      '${dose.scheduledDate} ${dose.scheduledTime}:00',
    );
    if (trigger == null || trigger.isBefore(DateTime.now())) return;

    final alarmId = _alarmIdForDose(dose);

    await AndroidAlarmManager.oneShotAt(
      trigger,
      alarmId,
      backgroundDoseAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );
  }

  int _alarmIdForDose(DoseRecord dose) {
    final key =
        '${dose.medicineId}-${dose.scheduledDate}-${dose.scheduledTime}';
    return key.hashCode & 0x7fffffff;
  }
}

@pragma('vm:entry-point')
Future<void> backgroundDoseAlarmCallback() async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  final date = DateFormat('yyyy-MM-dd').format(now);
  final time = DateFormat('HH:mm').format(now);

  final dueDoses = await DatabaseHelper.instance.getPendingDosesDueAtOrBefore(
    date,
    time,
  );

  if (dueDoses.isEmpty) return;

  final aiService = LocalAiService();
  final riskInferenceService = RiskInferenceService.instance;

  for (final dose in dueDoses) {
    final medicine = await DatabaseHelper.instance.getMedicineById(
      dose.medicineId,
    );
    if (medicine == null) continue;

    final summary = await DatabaseHelper.instance.getDoseSummary(medicine.id!);
    final totalDoses = summary['total'] ?? medicine.totalDoses;
    final takenDoses = summary['taken'] ?? 0;
    final missedDoses = summary['missed'] ?? 0;
    final delayMinutes = summary['delay'] ?? 0;

    final adherence = totalDoses <= 0 ? 0.0 : (takenDoses / totalDoses) * 100;
    final riskLevel = riskInferenceService
        .predictRisk(
          medicine: medicine.name,
          purpose: medicine.purpose,
          totalDoses: totalDoses,
          takenDoses: takenDoses,
          missedDoses: missedDoses,
          delayMinutes: delayMinutes,
          adherencePercentage: adherence,
        )
        .level;

    final instruction = aiService.generateInstruction(
      medicine.name,
      dose.scheduledTime,
      riskLevel,
      purpose: medicine.purpose,
    );

    try {
      await aiService.speakInstruction(instruction, language: 'en');
    } catch (_) {
      // If TTS still fails in a background context, the alarm still succeeded.
    }
  }
}
