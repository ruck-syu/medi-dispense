import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/database_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = Provider.of<DatabaseProvider>(context, listen: false);
      if (db.profile != null) {
        _nameController.text = db.profile!.name;
        _ageController.text = db.profile!.age.toString();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_nameController.text.isEmpty || _ageController.text.isEmpty) return;
    final age = int.tryParse(_ageController.text);
    if (age == null) return;

    Provider.of<DatabaseProvider>(
      context,
      listen: false,
    ).saveProfile(_nameController.text, age);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved successfully')));
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save Profile'),
              ),
            ),
            const SizedBox(height: 32),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medicines List',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            db.medicines.isEmpty
                ? const Text('No medicines added yet.')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: db.medicines.length,
                    itemBuilder: (context, index) {
                      final med = db.medicines[index];
                      return Card(
                        child: ListTile(
                          title: Text(med.name),
                          subtitle: Text('${med.dosage} - ${med.cause}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              if (med.id != null) {
                                db.deleteMedicine(med.id!);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
