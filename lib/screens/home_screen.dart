import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/database_provider.dart';
import '../services/database_helper.dart';
import 'add_medicine_screen.dart';
import 'bluetooth_devices_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<DoseRecord>> _selectedDateDoses;
  DateTime _selectedDate = DateTime.now();

  bool get _isTodaySelected {
    final now = DateTime.now();
    return now.year == _selectedDate.year &&
        now.month == _selectedDate.month &&
        now.day == _selectedDate.day;
  }

  @override
  void initState() {
    super.initState();
    _loadSelectedDateDoses();
  }

  String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return hhmm;

    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormat('hh:mm a').format(dt);
  }

  String _timePeriodLabel(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 'Day';

    final hour = int.tryParse(parts[0]);
    if (hour == null) return 'Day';

    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 21) return 'Evening';
    return 'Night';
  }

  void _loadSelectedDateDoses() {
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _selectedDateDoses = DatabaseHelper.instance.getDoseRecordsForDate(date);
  }

  void _refreshDoses() {
    setState(() {
      _loadSelectedDateDoses();
    });
  }

  void _changeSelectedDate(int daysDelta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: daysDelta));
      _loadSelectedDateDoses();
    });
  }

  Future<void> _pickScheduleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _loadSelectedDateDoses();
    });
  }

  Future<void> _markDoseAsTaken(DoseRecord dose) async {
    final now = DateTime.now();
    final doseParts = dose.scheduledTime.split(':');
    final doseHour = int.parse(doseParts[0]);
    final doseMinute = int.parse(doseParts[1]);

    final scheduledDateTime =
        DateTime(now.year, now.month, now.day, doseHour, doseMinute);
    final delayMinutes =
        now.difference(scheduledDateTime).inMinutes.clamp(0, 100000).toInt();
    final takenTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await DatabaseHelper.instance.markDoseAsTaken(
      dose.medicineId,
      dose.scheduledDate,
      dose.scheduledTime,
      delayMinutes,
      takenTime,
    );

    _refreshDoses();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Marked as taken${delayMinutes > 0 ? ' ($delayMinutes min late)' : ''}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _markDoseAsMissed(DoseRecord dose) async {
    await DatabaseHelper.instance.markDoseAsMissed(
      dose.medicineId,
      dose.scheduledDate,
      dose.scheduledTime,
    );

    _refreshDoses();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marked as missed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'taken':
        return Colors.green;
      case 'missed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'taken':
        return 'Taken';
      case 'missed':
        return 'Missed';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final btProvider = context.watch<BluetoothProvider>();
    final dbProvider = context.watch<DatabaseProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediDispense'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshDoses,
          ),
          if (btProvider.isConnected)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Reset Servo',
              onPressed: () async {
                await btProvider.resetServo();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Servo reset command sent')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const BluetoothDevicesDialog(),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: btProvider.isConnected
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      btProvider.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: btProvider.isConnected
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      btProvider.isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: btProvider.isConnected
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Switch(
                      value: btProvider.isConnected,
                      onChanged: (val) {
                        if (!val) {
                          btProvider.disconnect();
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => const BluetoothDevicesDialog(),
                          );
                        }
                      },
                      activeThumbColor: Colors.green.shade800,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isTodaySelected ? 'Today\'s Doses' : 'Schedule',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous day',
                      onPressed: () => _changeSelectedDate(-1),
                    ),
                    InkWell(
                      onTap: _pickScheduleDate,
                      child: Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next day',
                      onPressed: () => _changeSelectedDate(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isTodaySelected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Read-only view for non-today schedules',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),

          Expanded(
            child: FutureBuilder<List<DoseRecord>>(
              future: _selectedDateDoses,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final doses = snapshot.data ?? [];
                if (doses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No doses scheduled for ${DateFormat('MMM dd').format(_selectedDate)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: doses.length,
                  itemBuilder: (context, index) {
                    final dose = doses[index];
                    final medicine = dbProvider.getMedicineById(dose.medicineId);

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: dose.status == 'pending' ? 4 : 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        medicine?.name ?? 'Unknown Medicine',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (medicine != null)
                                        Text(
                                          '${medicine.dosage} - ${medicine.tabletsPerDose} tablet${medicine.tabletsPerDose > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(dose.status).withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusLabel(dose.status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(dose.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_formatTime(dose.scheduledTime)} (${_timePeriodLabel(dose.scheduledTime)})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (dose.takenTime != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12),
                                        child: Text(
                                          'Taken: ${_formatTime(dose.takenTime!)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (dose.delayMinutes > 0)
                                  Text(
                                    '+${dose.delayMinutes}m',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (dose.status == 'pending' && _isTodaySelected)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _markDoseAsMissed(dose),
                                      icon: const Icon(Icons.clear, size: 16),
                                      label: const Text('Missed'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _markDoseAsTaken(dose),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Taken'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicineScreen()),
          );
          if (created == true && context.mounted) {
            await Provider.of<DatabaseProvider>(context, listen: false).loadData();
            _refreshDoses();
          }
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
    );
  }
}
