import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/database_provider.dart';
import 'local_ai_service.dart';
import 'database_helper.dart';

class MedicineAutomationService {
  MedicineAutomationService._();

  static final MedicineAutomationService instance = MedicineAutomationService._();

  final LocalAiService _localAiService = LocalAiService();

  Timer? _pollTimer;
  bool _isProcessing = false;
  final Set<String> _triggeredEventKeys = <String>{};
  final Set<String> _missedDoseKeys = <String>{};

  void start(DatabaseProvider provider) {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkDueSchedules(provider),
    );

    // Immediate check once app starts.
    unawaited(_checkDueSchedules(provider));
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkDueSchedules(DatabaseProvider provider) async {
    if (_isProcessing) return;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final nowKey = '$today-${now.hour}-${now.minute}';
    final currentHHMM = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Get today's dose records
    final todaysDoses = await DatabaseHelper.instance.getDoseRecordsForDate(today);

    _isProcessing = true;
    try {
      // 1. Process due doses (trigger AI reminder)
      final dueSchedules = provider.schedules.where((schedule) {
        return schedule.isActive == 1 && schedule.time == currentHHMM;
      }).toList();

      if (dueSchedules.isNotEmpty) {
        for (final schedule in dueSchedules) {
          final eventKey = '$nowKey-${schedule.id}';
          if (_triggeredEventKeys.contains(eventKey)) {
            continue;
          }

          final medicine = provider.getMedicineById(schedule.medicineId);
          if (medicine == null) {
            continue;
          }

          // Check if dose record exists for this time
          final doseRecord = todaysDoses.firstWhere(
            (dose) =>
                dose.medicineId == medicine.id &&
                dose.scheduledTime == currentHHMM,
            orElse: () => DoseRecord(
              medicineId: medicine.id!,
              scheduledDate: today,
              scheduledTime: currentHHMM,
              status: 'pending',
            ),
          );

          // If dose status is still pending, trigger AI reminder
          if (doseRecord.status == 'pending') {
            await _handleDueMedicine(doseRecord, medicine, provider);
          }
          _triggeredEventKeys.add(eventKey);
        }
      }

      // 2. Auto-mark missed doses (doses that are past their time + grace period)
      const graceMinutes = 30; // Grace period after scheduled time
      for (final dose in todaysDoses) {
        if (dose.status != 'pending') continue; // Skip if already taken/missed

        final scheduledTime =
            TimeOfDay(
              hour: int.parse(dose.scheduledTime.split(':')[0]),
              minute: int.parse(dose.scheduledTime.split(':')[1]),
            );
        final scheduledDateTime =
            DateTime(now.year, now.month, now.day, scheduledTime.hour, scheduledTime.minute);
        final gracePeriodEnd = scheduledDateTime.add(Duration(minutes: graceMinutes));

        if (now.isAfter(gracePeriodEnd)) {
          final missedKey = '${dose.medicineId}-${dose.scheduledDate}-${dose.scheduledTime}';
          if (!_missedDoseKeys.contains(missedKey)) {
            await DatabaseHelper.instance.markDoseAsMissed(
              dose.medicineId,
              dose.scheduledDate,
              dose.scheduledTime,
            );
            _missedDoseKeys.add(missedKey);

            debugPrint(
              'Auto-marked as missed: ${dose.scheduledTime} (medicine_id: ${dose.medicineId})',
            );
          }
        }
      }

      _clearOldEventKeys(now);
    } catch (e, st) {
      debugPrint('Automation error: $e\n$st');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _handleDueMedicine(
    DoseRecord dose,
    Medicine medicine,
    DatabaseProvider provider,
  ) async {
    final metrics = await DatabaseHelper.instance.getAdherenceMetrics(medicine.id!);

    final totalDoses = medicine.totalDoses;
    final takenDoses = metrics?.takenDoses ?? 0;
    final missedDoses = metrics?.missedDoses ?? 0;
    final delayMinutes = metrics?.delayMinutes ?? 0;
    final adherencePercentage =
        totalDoses <= 0 ? 0.0 : (takenDoses / totalDoses) * 100;

    final result = await _localAiService.generateAndSpeak(
      medicine: medicine.name,
      purpose: medicine.purpose,
      time: dose.scheduledTime,
      totalDoses: totalDoses,
      takenDoses: takenDoses,
      missedDoses: missedDoses,
      delayMinutes: delayMinutes,
      adherencePercentage: adherencePercentage,
      language: 'en',
    );

    debugPrint(
      'Automation triggered for ${medicine.name} at ${dose.scheduledTime} | risk=${result.risk.level}',
    );
  }

  void _clearOldEventKeys(DateTime now) {
    final today = DateFormat('yyyy-MM-dd').format(now);
    final todayPrefix = '$today-';
    _triggeredEventKeys.removeWhere((key) => !key.startsWith(todayPrefix));

    // Clear old missed dose keys (older than 3 days)
    final thresholdDate =
        now.subtract(const Duration(days: 3));
    final thresholdDateStr = DateFormat('yyyy-MM-dd').format(thresholdDate);
    _missedDoseKeys.removeWhere((key) {
      final datePart = key.split('-').sublist(0, 3).join('-');
      return datePart.compareTo(thresholdDateStr) < 0;
    });
  }
}
