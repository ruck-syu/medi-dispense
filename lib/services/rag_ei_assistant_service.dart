import 'dart:math' as math;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:onenm_local_llm/onenm_local_llm.dart';

import 'database_helper.dart';

class RagAiQuestion {
  final String id;
  final String title;
  final String question;

  const RagAiQuestion({
    required this.id,
    required this.title,
    required this.question,
  });
}

class RagAiAssistantResponse {
  final String prompt;
  final String response;
  final String fallbackUsed;
  final String riskLevel;
  final double adherencePercentage;

  const RagAiAssistantResponse({
    required this.prompt,
    required this.response,
    required this.fallbackUsed,
    required this.riskLevel,
    required this.adherencePercentage,
  });
}

class RagAiAssistantService {
  RagAiAssistantService({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts();

  static const List<RagAiQuestion> questions = [
    RagAiQuestion(
      id: 'adherence',
      title: 'Medicines properly?',
      question: 'Am I taking my medicines properly?',
    ),
    RagAiQuestion(
      id: 'missed_today',
      title: 'Missed today?',
      question: 'Did I miss any medicines today?',
    ),
    RagAiQuestion(
      id: 'risk',
      title: 'Risk level',
      question: 'What is my health risk level?',
    ),
    RagAiQuestion(
      id: 'routine',
      title: 'Improve routine',
      question: 'How can I improve my routine?',
    ),
    RagAiQuestion(
      id: 'food',
      title: 'Food advice',
      question: 'What food should I follow based on my condition?',
    ),
    RagAiQuestion(
      id: 'missed_dose',
      title: 'If dose missed',
      question: 'What should I do if I miss a dose?',
    ),
    RagAiQuestion(
      id: 'overall',
      title: 'Overall advice',
      question: 'Give me overall health advice',
    ),
  ];

  final FlutterTts _flutterTts;
  OneNm? _model;
  bool _initializing = false;
  bool _initialized = false;
  String _status = 'Tap a question to start';

  String get status => _status;
  bool get isInitializing => _initializing;
  bool get isReady => _initialized;

  Future<void> initialize({void Function(String status)? onProgress}) async {
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      _updateStatus('Loading TinyLlama 1.1B Chat...', onProgress);
      _model = OneNm(
        model: OneNmModel.tinyllama,
        settings: const GenerationSettings(
          temperature: 0.4,
          topK: 40,
          topP: 0.9,
          maxTokens: 220,
          repeatPenalty: 1.1,
        ),
        onProgress: (status) => _updateStatus(status, onProgress),
        onRetryRequired: (message) async {
          _updateStatus(message, onProgress);
          return false;
        },
        debug: false,
      );
      await _model!.initialize();
      _initialized = true;
      _updateStatus('Ready', onProgress);
    } catch (e) {
      _initialized = false;
      _updateStatus('Model unavailable. Using safe fallback.', onProgress);
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  Future<RagAiAssistantResponse> answerQuestion({
    required RagAiQuestion question,
    bool speak = true,
  }) async {
    final contextData = await _buildContext();
    final prompt = _buildPrompt(contextData: contextData, question: question.question);

    String fallbackText = _buildFallbackText(contextData.riskLevel, question.question);
    String response = fallbackText;

    try {
      await initialize();
      final model = _model;
      if (model == null) {
        return RagAiAssistantResponse(
          prompt: prompt,
          response: fallbackText,
          fallbackUsed: 'Model not ready',
          riskLevel: contextData.riskLevel,
          adherencePercentage: contextData.adherencePercentage,
        );
      }

      final generated = await model.generate(prompt);
      response = _sanitizeResponse(generated);

      if (_isUnclear(response)) {
        response = fallbackText;
      } else if (_isTooShort(response)) {
        // Try one focused regeneration for richer output.
        final expandedPrompt =
            '$prompt\n\nYour previous answer was too short. Expand the response to around 15-20 sentences with all required sections.';
        final regenerated = await model.generate(expandedPrompt);
        final regeneratedSanitized = _sanitizeResponse(regenerated);
        if (!_isUnclear(regeneratedSanitized) && !_isTooShort(regeneratedSanitized)) {
          response = regeneratedSanitized;
        }
      }

      if (_isTooShort(response)) {
        response = '$response Please follow your medicine schedule and maintain a healthy lifestyle.';
      }
    } catch (_) {
      response = fallbackText;
    }

    if (speak) {
      await speakResponse(response);
    }

    return RagAiAssistantResponse(
      prompt: prompt,
      response: response,
      fallbackUsed: response == fallbackText ? 'fallback' : 'model',
      riskLevel: contextData.riskLevel,
      adherencePercentage: contextData.adherencePercentage,
    );
  }

  Future<void> speakResponse(String text, {String language = 'en'}) async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage(_normalizeLanguage(language));
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<_AssistantContextData> _buildContext() async {
    final profile = await DatabaseHelper.instance.getProfile();
    final medicines = await DatabaseHelper.instance.getMedicines();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayDoses = await DatabaseHelper.instance.getDoseRecordsForDate(today);

    int totalDoses = 0;
    int takenDoses = 0;
    int missedDoses = 0;
    int pendingDoses = 0;
    int delayMinutes = 0;
    final medicineLines = <String>[];

    for (final medicine in medicines) {
      final summary = await DatabaseHelper.instance.getDoseSummary(medicine.id!);
      final medicineTotal = summary['total'] ?? medicine.totalDoses;
      final medicineTaken = summary['taken'] ?? 0;
      final medicineMissed = summary['missed'] ?? 0;
      final medicinePending = summary['pending'] ?? 0;
      final medicineDelay = summary['delay'] ?? 0;
      final adherence = medicineTotal <= 0
          ? 0.0
          : (medicineTaken / medicineTotal) * 100;

      totalDoses += medicineTotal;
      takenDoses += medicineTaken;
      missedDoses += medicineMissed;
      pendingDoses += medicinePending;
      delayMinutes += medicineDelay;

      medicineLines.add(
        '- ${medicine.name} (${medicine.purpose.isNotEmpty ? medicine.purpose : medicine.cause}): '
        '${medicine.tabletsPerDose} tablet(s) per dose, ${medicine.timesPerDay} time(s) per day, '
        'total doses $medicineTotal, taken $medicineTaken, missed $medicineMissed, '
        'delay $medicineDelay minute(s), adherence ${adherence.toStringAsFixed(0)}%',
      );
    }

    final adherencePercentage = totalDoses <= 0
        ? 0.0
        : (takenDoses / math.max(totalDoses, 1)) * 100;
    final riskLevel = _riskLevel(adherencePercentage);
    final todayPending = todayDoses.where((dose) => dose.status == 'pending').length;

    return _AssistantContextData(
      name: profile?.name ?? 'User',
      age: profile?.age ?? 0,
      medicineLines: medicineLines,
      totalDoses: totalDoses,
      takenDoses: takenDoses,
      missedDoses: missedDoses,
      pendingDoses: pendingDoses,
      delayMinutes: delayMinutes,
      adherencePercentage: adherencePercentage,
      riskLevel: riskLevel,
      todayPending: todayPending,
    );
  }

  String _buildPrompt({
    required _AssistantContextData contextData,
    required String question,
  }) {
    final focusHint = _questionFocusHint(question);

    final buffer = StringBuffer()
      ..writeln('You are a smart and supportive health assistant.')
      ..writeln('')
      ..writeln('User Details:')
      ..writeln('Name: ${contextData.name}')
      ..writeln('Age: ${contextData.age}')
      ..writeln('')
      ..writeln('Medicine Data:');

    if (contextData.medicineLines.isEmpty) {
      buffer.writeln('- No medicines recorded yet.');
    } else {
      for (final line in contextData.medicineLines) {
        buffer.writeln(line);
      }
    }

    buffer
      ..writeln('')
      ..writeln('Health Status:')
      ..writeln('Total doses: ${contextData.totalDoses}')
      ..writeln('Taken doses: ${contextData.takenDoses}')
      ..writeln('Missed doses: ${contextData.missedDoses}')
      ..writeln('Pending doses: ${contextData.pendingDoses}')
      ..writeln('Delay minutes: ${contextData.delayMinutes}')
      ..writeln('Adherence: ${contextData.adherencePercentage.toStringAsFixed(0)}%')
      ..writeln('Risk level: ${contextData.riskLevel}')
      ..writeln('Today pending doses: ${contextData.todayPending}')
      ..writeln('Question intent focus: $focusHint')
      ..writeln('')
      ..writeln('Question:')
      ..writeln(question)
      ..writeln('')
      ..writeln('Instructions:')
      ..writeln('* Answer ONLY based on the question')
      ..writeln('* Use the user data to personalize the response')
      ..writeln('* Write a detailed answer (around 15-20 sentences)')
      ..writeln('* Do NOT repeat the same sentence')
      ..writeln('* Do NOT give medical prescriptions')
      ..writeln('* Keep language simple and clear')
      ..writeln('* Use section-based output in paragraph style')
      ..writeln('* Each section should contain 2-4 sentences')
      ..writeln('* Use missed doses, medicine type, and age in reasoning')
      ..writeln('')
      ..writeln('Format:')
      ..writeln('1. Current Situation')
      ..writeln('2. Problem Analysis')
      ..writeln('3. Suggestions for Improvement')
      ..writeln('4. Food & Lifestyle Advice')
      ..writeln('5. Final Advice')
      ..writeln('')
      ..writeln('Answer:');

    return buffer.toString();
  }

  String _sanitizeResponse(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return cleaned;

    // Keep output relatively long and readable while avoiding runaway text.
    final sentences = _sentenceList(cleaned);
    if (sentences.length > 22) {
      return sentences.take(22).join(' ');
    }
    return cleaned;
  }

  bool _isUnclear(String text) {
    final lower = text.toLowerCase();
    return text.trim().length < 20 ||
        lower.contains('as an ai') ||
        lower.contains('i cannot') ||
        lower.contains('not sure');
  }

  bool _isTooShort(String text) {
    final sentenceCount = _sentenceList(text).length;
    return sentenceCount < 15;
  }

  List<String> _sentenceList(String text) {
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  String _questionFocusHint(String question) {
    final q = question.toLowerCase();
    if (q.contains('food')) {
      return 'Prioritize diet quality, meal timing, hydration, and food habits related to the user condition.';
    }
    if (q.contains('miss')) {
      return 'Prioritize missed doses, adherence barriers, reminders, and practical recovery steps.';
    }
    if (q.contains('risk')) {
      return 'Prioritize adherence trend, missed-dose impact, and why current risk level matters.';
    }
    if (q.contains('routine')) {
      return 'Prioritize daily schedule structure, consistency, and habit-building methods.';
    }
    return 'Stay focused on the exact question and connect advice to user medicine history and adherence.';
  }

  String _buildFallbackText(String riskLevel, String question) {
    if (riskLevel == 'HIGH') {
      return 'Please follow your medicine schedule carefully and avoid skipping doses. Keep a fixed routine for food, sleep, and hydration so your body responds better. Track your doses daily and ask a caregiver to support reminders. If you feel worse or symptoms continue, consult a doctor as soon as possible.';
    }
    if (question.toLowerCase().contains('food')) {
      return 'Please follow a balanced food routine with regular meal timings and enough water through the day. Prefer home-cooked meals, vegetables, and protein-rich foods while reducing highly oily and sugary items. Avoid skipping meals when taking regular medicines. If your condition has specific diet restrictions, follow your doctor\'s advice closely.';
    }
    return 'Please follow your medicine schedule consistently and set fixed reminders for every dose. Keep a daily log of taken, missed, and delayed medicines so you can improve adherence over time. Support your routine with healthy meals, proper sleep, and hydration. If you are uncertain about any symptom or missed-dose decision, consult a doctor.';
  }

  String _riskLevel(double adherence) {
    if (adherence >= 80) return 'LOW';
    if (adherence >= 50) return 'MEDIUM';
    return 'HIGH';
  }

  void _updateStatus(String status, void Function(String status)? onProgress) {
    _status = status;
    if (onProgress != null) {
      onProgress(status);
    }
  }

  String _normalizeLanguage(String language) {
    final lower = language.toLowerCase();
    if (lower.startsWith('hi')) return 'hi-IN';
    if (lower.startsWith('kn')) return 'kn-IN';
    return 'en-US';
  }
}

class _AssistantContextData {
  final String name;
  final int age;
  final List<String> medicineLines;
  final int totalDoses;
  final int takenDoses;
  final int missedDoses;
  final int pendingDoses;
  final int delayMinutes;
  final double adherencePercentage;
  final String riskLevel;
  final int todayPending;

  _AssistantContextData({
    required this.name,
    required this.age,
    required this.medicineLines,
    required this.totalDoses,
    required this.takenDoses,
    required this.missedDoses,
    required this.pendingDoses,
    required this.delayMinutes,
    required this.adherencePercentage,
    required this.riskLevel,
    required this.todayPending,
  });
}
