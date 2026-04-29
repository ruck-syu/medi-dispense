import 'package:flutter_tts/flutter_tts.dart';

class LocalRiskResult {
  final String level;
  final String label;

  const LocalRiskResult({required this.level, required this.label});
}

class OfflineAiResult {
  final LocalRiskResult risk;
  final String instructionText;

  const OfflineAiResult({required this.risk, required this.instructionText});
}

class LocalAiService {
  LocalAiService({FlutterTts? flutterTts}) : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  static const Map<String, LocalRiskResult> riskOptions = {
    'LOW': LocalRiskResult(level: 'LOW', label: 'Low risk'),
    'MEDIUM': LocalRiskResult(level: 'MEDIUM', label: 'Medium risk'),
    'HIGH': LocalRiskResult(level: 'HIGH', label: 'High risk'),
  };

  static const Map<String, List<String>> medicineKeywords = {
    'BP': ['bp', 'blood pressure', 'hypertension', 'high bp'],
    'Diabetes': ['diabetes', 'sugar'],
    'Fever': ['fever', 'high fever'],
    'Cough': ['cough', 'cold'],
    'Headache': ['headache', 'migraine'],
    'Cholesterol': ['cholesterol'],
    'Asthma': ['asthma'],
    'Heart': ['heart'],
    'Thyroid': ['thyroid'],
    'Pain': ['pain', 'pain relief'],
  };

  LocalRiskResult predictRisk({
    required int totalDoses,
    required int takenDoses,
    required int missedDoses,
    required int delayMinutes,
    required double adherencePercentage,
  }) {
    final normalized = adherencePercentage.isFinite ? adherencePercentage : 0.0;

    if (normalized >= 80) {
      return riskOptions['LOW']!;
    }
    if (normalized >= 50) {
      return riskOptions['MEDIUM']!;
    }
    return riskOptions['HIGH']!;
  }

  String? _detectCategory(String medicine, {String? purpose}) {
    final combined = '${medicine.toLowerCase()} ${(purpose ?? '').toLowerCase()}';

    for (final entry in medicineKeywords.entries) {
      for (final keyword in entry.value) {
        if (combined.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  String _timePersonalization(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 'Please follow your routine.';
    final hour = int.tryParse(parts[0]);
    if (hour == null) return 'Please follow your routine.';

    if (hour >= 5 && hour < 12) {
      return 'Good morning. Start your day with care.';
    }
    if (hour >= 12 && hour < 17) {
      return 'Good afternoon. Stay hydrated and keep your schedule.';
    }
    if (hour >= 17 && hour < 21) {
      return 'Good evening. Keep your routine consistent.';
    }
    return 'Good night. Take your medicine and get proper rest.';
  }

  String generateInstruction(
    String medicine,
    String time,
    String riskLevel, {
    String? purpose,
  }) {
    final base = 'It is time to take your $medicine medicine ($time). ';
    final category = _detectCategory(medicine, purpose: purpose);
    String message;

    switch (category) {
      case 'BP':
        message =
          '${base}Please take your blood pressure tablet now. '
            'Drink one to two glasses of water. '
            'Avoid salty and oily foods. '
            'Take rest for at least 15 to 20 minutes. '
            'Maintain a calm and stress-free environment. ';
        break;
      case 'Diabetes':
        message =
          '${base}Please take your diabetes medicine now. '
            'Eat your meal on time after taking medicine. '
            'Avoid sugary foods and drinks. '
            'Drink enough water. '
            'Monitor your blood sugar regularly. ';
        break;
      case 'Fever':
        message =
          '${base}Please take your fever tablet now. '
            'Drink plenty of fluids like water or juice. '
            'Take proper rest. '
            'Avoid cold foods and stay warm. ';
        break;
      case 'Cough':
        message =
          '${base}Please take your cough medicine now. '
            'Drink warm water. '
            'Avoid cold drinks and dust exposure. '
            'Take proper rest. ';
        break;
      case 'Headache':
        message =
          '${base}Please take your headache tablet now. '
            'Take rest in a quiet place. '
            'Avoid bright light and loud noise. '
            'Drink enough water. ';
        break;
      case 'Cholesterol':
        message =
          '${base}Please take your cholesterol medicine now. '
            'Avoid oily and fatty foods. '
            'Include healthy vegetables in your diet. '
            'Do light physical activity regularly. ';
        break;
      case 'Asthma':
        message =
          '${base}Please take your asthma medication now. '
            'Avoid dust and allergens. '
            'Keep your inhaler nearby. '
            'Take rest if breathing is difficult. ';
        break;
      case 'Heart':
        message =
          '${base}Please take your heart medication now. '
            'Avoid stress and heavy activity. '
            'Maintain a healthy diet. '
            'Take proper rest. ';
        break;
      case 'Thyroid':
        message =
          '${base}Please take your thyroid medicine now on an empty stomach. '
            'Wait at least 30 minutes before eating. '
            'Maintain a proper routine. ';
        break;
      case 'Pain':
        message =
          '${base}Please take your pain relief medicine now. '
            'Take rest and avoid heavy physical activity. '
            'Drink enough water. ';
        break;
      default:
        message = '${base}Please take your medicine and follow your routine. ';
    }

    if (riskLevel == 'HIGH') {
      message += 'You have a high risk level. Please do not skip medicines and consult a doctor if needed. ';
    } else if (riskLevel == 'MEDIUM') {
      message += 'Try to follow your schedule properly and avoid missing doses. ';
    } else {
      message += 'Good job maintaining your schedule. Keep it up. ';
    }

    message += '${_timePersonalization(time)} ';

    return message;
  }

  Future<void> speakInstruction(String text, {String language = 'en'}) async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage(_normalizeLanguage(language));
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<OfflineAiResult> generateAndSpeak({
    required String medicine,
    required String time,
    required int totalDoses,
    required int takenDoses,
    required int missedDoses,
    required int delayMinutes,
    required double adherencePercentage,
    String? purpose,
    String language = 'en',
  }) async {
    final risk = predictRisk(
      totalDoses: totalDoses,
      takenDoses: takenDoses,
      missedDoses: missedDoses,
      delayMinutes: delayMinutes,
      adherencePercentage: adherencePercentage,
    );
    final instruction = generateInstruction(
      medicine,
      time,
      risk.level,
      purpose: purpose,
    );
    await speakInstruction(instruction, language: language);
    return OfflineAiResult(risk: risk, instructionText: instruction);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  String _normalizeLanguage(String language) {
    final lower = language.toLowerCase();
    if (lower.startsWith('hi')) return 'hi-IN';
    if (lower.startsWith('kn')) return 'kn-IN';
    return 'en-US';
  }
}
