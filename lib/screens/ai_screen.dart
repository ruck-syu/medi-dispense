import 'package:flutter/material.dart';

import '../services/rag_ei_assistant_service.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final RagAiAssistantService _assistant = RagAiAssistantService();

  bool _loading = true;
  bool _working = false;
  bool _voiceEnabled = true;
  String _status = 'Preparing TinyLlama...';
  String? _selectedQuestionId;
  String? _response;
  String? _prompt;
  String? _riskLevel;
  double? _adherence;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootAssistant();
  }

  Future<void> _bootAssistant() async {
    setState(() {
      _loading = true;
      _status = 'Loading local model...';
      _error = null;
    });

    try {
      await _assistant.initialize(onProgress: (status) {
        if (!mounted) return;
        setState(() {
          _status = status;
        });
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Ready';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Model will fall back to safe advice';
        _error = e.toString();
      });
    }
  }

  Future<void> _askQuestion(RagAiQuestion question) async {
    setState(() {
      _working = true;
      _selectedQuestionId = question.id;
      _error = null;
    });

    try {
      final answer = await _assistant.answerQuestion(
        question: question,
        speak: _voiceEnabled,
      );

      if (!mounted) return;
      setState(() {
        _response = answer.response;
        _prompt = answer.prompt;
        _riskLevel = answer.riskLevel;
        _adherence = answer.adherencePercentage;
        _status = answer.fallbackUsed == 'model'
            ? 'Answered with TinyLlama'
            : 'Answered with safe fallback';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _response = 'Please follow your medicine schedule and consult a doctor if needed.';
        _status = 'Fallback response shown';
      });
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Color _statusColor() {
    if (_status.toLowerCase().contains('ready') ||
        _status.toLowerCase().contains('answered')) {
      return Colors.green;
    }
    if (_error != null) {
      return Colors.red;
    }
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAG-AI Assistant'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _bootAssistant,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload model',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.memory, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'TinyLlama 1.1B Chat runs fully on device.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: TextStyle(color: _statusColor()),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Ask one of the fixed health questions below. The assistant uses your local profile and medicine history to build the prompt.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _voiceEnabled,
            onChanged: (value) {
              setState(() {
                _voiceEnabled = value;
              });
            },
            title: const Text('Speak answer automatically'),
            subtitle: const Text('Uses on-device TTS after the model responds'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a question',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...RagAiAssistantService.questions.map((question) {
            final selected = _selectedQuestionId == question.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton(
                onPressed: (_working || _loading) ? null : () => _askQuestion(question),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected ? Colors.teal : Colors.white,
                  foregroundColor: selected ? Colors.white : Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  side: BorderSide(color: Colors.teal.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.question_answer_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question.question,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          if (_working) const LinearProgressIndicator(),
          if (_response != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Response',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _response!,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_riskLevel != null)
                          Chip(label: Text('Risk: $_riskLevel')),
                        if (_adherence != null)
                          Chip(label: Text('Adherence: ${_adherence!.toStringAsFixed(0)}%')),
                      ],
                    ),
                    if (_prompt != null) ...[
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Prompt used'),
                        children: [
                          SelectableText(
                            _prompt!,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          const Text(
            'Model note: TinyLlama downloads once, then runs offline on device from cache.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
