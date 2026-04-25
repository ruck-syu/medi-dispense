import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/database_provider.dart';
import 'add_schedule_screen.dart';
import 'bluetooth_devices_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final btProvider = Provider.of<BluetoothProvider>(context);
    final dbProvider = Provider.of<DatabaseProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediDispense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset Servo',
            onPressed: () async {
              if (btProvider.isConnected) {
                await btProvider.resetServo();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Servo reset command sent')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Not connected to dispenser')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Bluetooth Pill
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
                            builder: (context) =>
                                const BluetoothDevicesDialog(),
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

          // Schedules List
          Expanded(
            child: dbProvider.schedules.isEmpty
                ? const Center(child: Text('No schedules added.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dbProvider.schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = dbProvider.schedules[index];
                      final medicine = dbProvider.getMedicineById(
                        schedule.medicineId,
                      );

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.medication,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medicine?.name ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text('Time: ${schedule.time}'),
                                    Text(
                                      'Compartment: ${schedule.compartment}',
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Switch(
                                    value: schedule.isActive == 1,
                                    onChanged: (val) {
                                      dbProvider.toggleSchedule(schedule);
                                    },
                                    activeThumbColor: Colors.teal,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      if (btProvider.isConnected) {
                                        btProvider.deleteScheduleFromDevice(
                                          schedule.time,
                                          schedule.compartment,
                                        );
                                      }
                                      dbProvider.deleteSchedule(schedule.id!);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddScheduleScreen()),
          );
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
    );
  }
}
