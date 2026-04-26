import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/database_provider.dart';
import '../services/background_dose_scheduler.dart';
import '../services/database_helper.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  static const List<String> _purposeOptions = [
    'Blood Pressure',
    'Diabetes',
    'Fever',
    'Cough/Cold',
    'Headache',
    'Pain Relief',
    'Thyroid',
    'Heart',
    'Asthma',
    'Cholesterol',
    'Custom',
  ];
  
  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _purposeController;
  late TextEditingController _tabletsPerDoseController;
  late TextEditingController _timesPerDayController;
  late TextEditingController _totalDaysController;
  
  // Form values
  int _tabletsPerDose = 1;
  int _timesPerDay = 1;
  int _totalDays = 7;
  DateTime? _startDate;
  List<TimeOfDay> _scheduledTimes = [];
  String _selectedPurpose = 'Custom';
  bool _isSaving = false;

  List<TimeOfDay> _defaultDoseTimes(int count) {
    switch (count) {
      case 1:
        return const [TimeOfDay(hour: 8, minute: 0)];
      case 2:
        return const [
          TimeOfDay(hour: 8, minute: 0),
          TimeOfDay(hour: 20, minute: 0),
        ];
      case 3:
        return const [
          TimeOfDay(hour: 8, minute: 0),
          TimeOfDay(hour: 14, minute: 0),
          TimeOfDay(hour: 20, minute: 0),
        ];
      default:
        return const [
          TimeOfDay(hour: 8, minute: 0),
          TimeOfDay(hour: 13, minute: 0),
          TimeOfDay(hour: 18, minute: 0),
          TimeOfDay(hour: 22, minute: 0),
        ];
    }
  }

  String _formatTime(TimeOfDay time) {
    final date = DateTime(2000, 1, 1, time.hour, time.minute);
    return DateFormat('hh:mm a').format(date);
  }

  String _periodLabel(TimeOfDay time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 21) return 'Evening';
    return 'Night';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageController = TextEditingController();
    _purposeController = TextEditingController();
    _tabletsPerDoseController = TextEditingController(text: '1');
    _timesPerDayController = TextEditingController(text: '1');
    _totalDaysController = TextEditingController(text: '7');
    _startDate = DateTime.now();
    _scheduledTimes = _defaultDoseTimes(_timesPerDay);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _purposeController.dispose();
    _tabletsPerDoseController.dispose();
    _timesPerDayController.dispose();
    _totalDaysController.dispose();
    super.dispose();
  }

  void _onTimesPerDayTextChanged(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return;
    if (parsed < 1 || parsed > 4) return;

    if (_timesPerDay != parsed) {
      _updateTimesPerDay(parsed.toDouble());
    }
  }

  void _normalizeScheduledTimes({required int targetCount}) {
    final safeCount = targetCount.clamp(1, 4);
    final defaults = _defaultDoseTimes(safeCount);
    final normalized = <TimeOfDay>[];

    for (int i = 0; i < safeCount; i++) {
      if (i < _scheduledTimes.length) {
        normalized.add(_scheduledTimes[i]);
      } else {
        normalized.add(defaults[i]);
      }
    }

    normalized.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });

    _scheduledTimes = normalized;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickTime(int index) async {
    _normalizeScheduledTimes(targetCount: _timesPerDay);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTimes.isNotEmpty && index < _scheduledTimes.length
          ? _scheduledTimes[index]
          : TimeOfDay.now(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _normalizeScheduledTimes(targetCount: _timesPerDay);

        if (index < _scheduledTimes.length) {
          _scheduledTimes[index] = picked;
        } else {
          _scheduledTimes.add(picked);
        }
        // Sort times
        _scheduledTimes.sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });
    }
  }

  void _updateTimesPerDay(double value) {
    setState(() {
      _timesPerDay = value.round();
      _timesPerDayController.text = _timesPerDay.toString();
      _timesPerDayController.selection = TextSelection.fromPosition(
        TextPosition(offset: _timesPerDayController.text.length),
      );

      _normalizeScheduledTimes(targetCount: _timesPerDay);
    });
  }

  Future<void> _saveMedicine() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    _tabletsPerDose = int.tryParse(_tabletsPerDoseController.text.trim()) ?? 1;
    _timesPerDay = int.tryParse(_timesPerDayController.text.trim()) ?? 1;
    _totalDays = int.tryParse(_totalDaysController.text.trim()) ?? 7;

    if (_timesPerDay < 1) _timesPerDay = 1;
    if (_timesPerDay > 4) _timesPerDay = 4;

    _normalizeScheduledTimes(targetCount: _timesPerDay);

    final purposeText = _purposeController.text.trim();
    final effectivePurpose = purposeText.isNotEmpty
        ? purposeText
        : (_selectedPurpose == 'Custom' ? 'General' : _selectedPurpose);
    
    if (_scheduledTimes.length != _timesPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please set all $_timesPerDay scheduled times'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final startDateStr =
        '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}';

    // Create medicine
    final medicine = Medicine(
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      cause: effectivePurpose,
      tabletsPerDose: _tabletsPerDose,
      timesPerDay: _timesPerDay,
      totalDays: _totalDays,
      purpose: effectivePurpose,
      startDate: startDateStr,
    );

    try {
      // Save medicine to database
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final savedMedicine = await dbProvider.addMedicine(medicine);

      // Save selected times as active schedules
      for (int i = 0; i < _scheduledTimes.length; i++) {
        final time = _scheduledTimes[i];
        final timeString =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        await DatabaseHelper.instance.addSchedule(
          Schedule(
            medicineId: savedMedicine.id!,
            time: timeString,
            compartment: i + 1,
            isActive: 1,
          ),
        );
      }

      // Generate dose records from the saved schedule rows
      await DatabaseHelper.instance.generateDoseRecords(savedMedicine);
      try {
        await BackgroundDoseScheduler.instance.scheduleAllPendingDoseAlarms();
      } catch (_) {
        // Do not block save flow if alarm scheduling fails on a device.
      }
      await dbProvider.loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${savedMedicine.name} added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving medicine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medicine'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine Name
              const Text(
                'Medicine Name',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., BP Tablet',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter medicine name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Dosage
              const Text(
                'Dosage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  hintText: 'e.g., 500mg',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter dosage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Tablets per Dose
              const Text(
                'Tablets per Dose',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tabletsPerDoseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter tablets per dose (1-5)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value.trim());
                  if (parsed != null && parsed >= 1 && parsed <= 5) {
                    setState(() {
                      _tabletsPerDose = parsed;
                    });
                  }
                },
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 1 || parsed > 5) {
                    return 'Enter a value between 1 and 5';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Times per Day
              const Text(
                'Times per Day',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _timesPerDayController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter times per day (1-4)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _onTimesPerDayTextChanged,
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 1 || parsed > 4) {
                    return 'Enter a value between 1 and 4';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Duration (Days)
              const Text(
                'Duration (Days)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter duration in days (1-365)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value.trim());
                  if (parsed != null && parsed >= 1 && parsed <= 365) {
                    setState(() {
                      _totalDays = parsed;
                    });
                  }
                },
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 1 || parsed > 365) {
                    return 'Enter a value between 1 and 365';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Purpose/Cause
              const Text(
                'Purpose / Indication (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedPurpose,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _purposeOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedPurpose = value;
                    if (value != 'Custom') {
                      _purposeController.text = value;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _purposeController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: _selectedPurpose == 'Custom'
                      ? 'Type custom purpose (e.g., hypertension, sugar)'
                      : 'You can edit selected purpose or type custom',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Start Date
              const Text(
                'Start Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _startDate != null
                            ? DateFormat('MMM dd, yyyy').format(_startDate!)
                            : 'Select date',
                      ),
                      const Icon(Icons.calendar_today, color: Colors.teal),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Scheduled Times
              const Text(
                'Scheduled Times',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...List.generate(_timesPerDay, (index) {
                final time = index < _scheduledTimes.length
                    ? _scheduledTimes[index]
                    : _defaultDoseTimes(_timesPerDay)[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => _pickTime(index),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Dose ${index + 1}'),
                          Row(
                            children: [
                              Text(
                                '${_formatTime(time)} (${_periodLabel(time)})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.access_time, color: Colors.teal),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Doses: ${_timesPerDay * _totalDays}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Tablets Required: ${_tabletsPerDose * _timesPerDay * _totalDays}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Duration: $_totalDays days',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Add Medicine',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
