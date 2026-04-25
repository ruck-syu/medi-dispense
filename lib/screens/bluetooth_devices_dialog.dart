import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';

class BluetoothDevicesDialog extends StatefulWidget {
  const BluetoothDevicesDialog({super.key});

  @override
  State<BluetoothDevicesDialog> createState() => _BluetoothDevicesDialogState();
}

class _BluetoothDevicesDialogState extends State<BluetoothDevicesDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BluetoothProvider>(context, listen: false).startScan();
    });
  }

  @override
  void dispose() {
    // Provider.of<BluetoothProvider>(context, listen: false).stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btProvider = Provider.of<BluetoothProvider>(context);

    return AlertDialog(
      title: const Text('Connect to Dispenser'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (btProvider.isScanning) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: btProvider.scanResults.length,
                itemBuilder: (context, index) {
                  final result = btProvider.scanResults[index];
                  final deviceName = result.device.advName.isNotEmpty
                      ? result.device.advName
                      : result.device.remoteId.str;

                  return ListTile(
                    title: Text(deviceName),
                    subtitle: Text(result.device.remoteId.str),
                    onTap: () async {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connecting...')),
                        );
                        Navigator.pop(context);
                      }
                      await btProvider.connect(result.device);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
