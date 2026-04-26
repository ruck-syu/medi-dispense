import 'package:flutter/material.dart';

import '../services/local_ai_service.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final LocalAiService _localAiService = LocalAiService();

  bool _loadingStatus = false;
  bool _testing = false;
  String? _error;
  OfflineAiResult? _testResponse;

  final String _sampleMedicine = 'BP';
  final String _sampleTime = '09:10';
  final int _sampleTotalDoses = 10;
  final int _sampleTakenDoses = 7;
  final int _sampleMissedDoses = 3;
  final int _sampleDelayMinutes = 15;
  final double _sampleAdherence = 70;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _loadingStatus = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) {
      setState(() {
        _loadingStatus = false;
      });
    }
  }

  Future<void> _runTestInference() async {
    setState(() {
      _testing = true;
      _error = null;
    });

    try {
      final response = await _localAiService.generateAndSpeak(
        medicine: _sampleMedicine,
        time: _sampleTime,
        totalDoses: _sampleTotalDoses,
        takenDoses: _sampleTakenDoses,
        missedDoses: _sampleMissedDoses,
        delayMinutes: _sampleDelayMinutes,
        adherencePercentage: _sampleAdherence,
        language: 'en',
      );

      setState(() {
        _testResponse = response;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline AI Assistant'),
        actions: [
          IconButton(
            onPressed: _loadingStatus ? null : _refreshStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'AI now runs fully offline inside Flutter.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (_loadingStatus) const LinearProgressIndicator() else _buildStatusSection(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _testing ? null : _runTestInference,
            icon: const Icon(Icons.science_outlined),
            label: Text(_testing ? 'Testing Offline AI...' : 'Run Offline AI Demo'),
          ),
          const SizedBox(height: 12),
          if (_testResponse != null) _buildTestResult(_testResponse!),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusCard(
          title: 'Model 1: Risk Prediction',
          subtitle: 'Rule-based approximation from adherence percentage',
          ready: true,
        ),
        const SizedBox(height: 8),
        _statusCard(
          title: 'Model 2: Voice Assistant',
          subtitle: 'Rule-based instruction generator + Flutter TTS',
          ready: true,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline logic used',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Risk thresholds: >=80 LOW, 50-79 MEDIUM, <50 HIGH'),
                const SizedBox(height: 4),
                const Text('Instruction templates: medicine-specific messages with risk-based advice'),
                const SizedBox(height: 4),
                const Text('Speech engine: Flutter TTS, no backend/API calls'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required String title,
    required String subtitle,
    required bool ready,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          ready ? Icons.check_circle : Icons.error,
          color: ready ? Colors.green : Colors.red,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildTestResult(OfflineAiResult response) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risk Prediction: ${response.risk.level}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(response.instructionText),
            const SizedBox(height: 8),
            Text(
              'Sample input: adherence $_sampleAdherence%, doses $_sampleTakenDoses/$_sampleTotalDoses, missed $_sampleMissedDoses, delay $_sampleDelayMinutes min',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
