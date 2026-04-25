import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/database_provider.dart';
import '../providers/bluetooth_provider.dart';

class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({super.key});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  Medicine? _selectedMedicine;
  TimeOfDay? _selectedTime;
  int _selectedCompartment = 1;

  final List<int> _compartments = [1, 2, 3, 4];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = Provider.of<DatabaseProvider>(context);
    final isOccupied = db.schedules.any(
      (s) => s.isActive == 1 && s.compartment == _selectedCompartment,
    );
    if (isOccupied) {
      for (var comp in _compartments) {
        if (!db.schedules.any((s) => s.isActive == 1 && s.compartment == comp)) {
          _selectedCompartment = comp;
          break;
        }
      }
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveSchedule() async {
    if (_selectedMedicine == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select medicine and time')),
      );
      return;
    }

    final db = Provider.of<DatabaseProvider>(context, listen: false);
    
    // Check if compartment is already active
    final isOccupied = db.schedules.any(
      (s) => s.isActive == 1 && s.compartment == _selectedCompartment,
    );

    if (isOccupied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compartment $_selectedCompartment is already in use.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    // Formatting time as HH:MM
    final timeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    // Add to Local DB
    await db.addSchedule(_selectedMedicine!.id!, timeStr, _selectedCompartment);

    // Add to Arduino via BLE
    if (btProvider.isConnected) {
      await btProvider.addScheduleToDevice(timeStr, _selectedCompartment);
    }

    navigator.pop();
    }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Schedule')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Medicine',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButton<Medicine>(
              isExpanded: true,
              value: _selectedMedicine,
              hint: const Text('Choose a medicine'),
              items: db.medicines.map((Medicine med) {
                return DropdownMenuItem<Medicine>(
                  value: med,
                  child: Text(med.name),
                );
              }).toList(),
              onChanged: (Medicine? value) {
                setState(() {
                  _selectedMedicine = value;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Time',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'Choose Time',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Compartment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButton<int>(
              isExpanded: true,
              value: _selectedCompartment,
              items: _compartments.map((int comp) {
                final isOccupied = db.schedules.any(
                  (s) => s.isActive == 1 && s.compartment == comp,
                );
                return DropdownMenuItem<int>(
                  value: comp,
                  enabled: !isOccupied,
                  child: Text(
                    isOccupied ? 'Compartment $comp (In Use)' : 'Compartment $comp',
                    style: TextStyle(
                      color: isOccupied ? Colors.grey : null,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() {
                    _selectedCompartment = value;
                  });
                }
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSchedule,
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Save Schedule',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
