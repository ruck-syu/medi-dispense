import '../models/risk_model.dart';

class RiskInferenceResult {
  final String level;
  final List<double> scores;
  final bool fallbackUsed;

  const RiskInferenceResult({
    required this.level,
    required this.scores,
    required this.fallbackUsed,
  });
}

class RiskInferenceService {
  RiskInferenceService._();

  static final RiskInferenceService instance = RiskInferenceService._();

  final RiskModel _riskModel = RiskModel();

  // Confirmed from training pipeline and user mapping:
  // input[0] medicine_type (encoded)
  // input[1] total_doses
  // input[2] taken_doses
  // input[3] missed_doses
  // input[4] delay_minutes
  // input[5] adherence_percentage
  static const Map<int, String> _scoreIndexToLevel = {
    0: 'HIGH',
    1: 'LOW',
    2: 'MEDIUM',
  };

  // Mirrors sklearn LabelEncoder alphabetical order over class labels:
  // Asthma, BP, Cholesterol, Cough, Diabetes, Fever, Headache, Heart, Pain Relief, Thyroid
  static const Map<String, int> _medicineTypeEncoding = {
    'Asthma': 0,
    'BP': 1,
    'Cholesterol': 2,
    'Cough': 3,
    'Diabetes': 4,
    'Fever': 5,
    'Headache': 6,
    'Heart': 7,
    'Pain Relief': 8,
    'Thyroid': 9,
  };

  static const Map<String, List<String>> _categoryKeywords = {
    'BP': ['bp', 'blood pressure', 'hypertension', 'high bp'],
    'Diabetes': ['diabetes', 'sugar'],
    'Fever': ['fever', 'high fever'],
    'Cough': ['cough', 'cold'],
    'Headache': ['headache', 'migraine'],
    'Cholesterol': ['cholesterol'],
    'Asthma': ['asthma'],
    'Heart': ['heart'],
    'Thyroid': ['thyroid'],
    'Pain Relief': ['pain', 'pain relief'],
  };

  RiskInferenceResult predictRisk({
    required String medicine,
    String? purpose,
    required int totalDoses,
    required int takenDoses,
    required int missedDoses,
    required int delayMinutes,
    required double adherencePercentage,
  }) {
    final input = buildModelInput(
      medicine: medicine,
      purpose: purpose,
      totalDoses: totalDoses,
      takenDoses: takenDoses,
      missedDoses: missedDoses,
      delayMinutes: delayMinutes,
      adherencePercentage: adherencePercentage,
    );
    final normalizedAdherence = adherencePercentage.isFinite
        ? adherencePercentage.clamp(0, 100).toDouble()
        : 0.0;
    if (input == null) return _fallbackResult(normalizedAdherence);

    try {
      final scores = _riskModel.score(input);
      final level = decodeScores(
        scores,
        fallbackAdherence: normalizedAdherence,
      );
      final fallbackUsed = scores.length != 3;

      return RiskInferenceResult(
        level: level,
        scores: List<double>.unmodifiable(scores),
        fallbackUsed: fallbackUsed,
      );
    } catch (_) {
      return _fallbackResult(normalizedAdherence);
    }
  }

  List<double>? buildModelInput({
    required String medicine,
    String? purpose,
    required int totalDoses,
    required int takenDoses,
    required int missedDoses,
    required int delayMinutes,
    required double adherencePercentage,
  }) {
    final normalizedAdherence = adherencePercentage.isFinite
        ? adherencePercentage.clamp(0, 100).toDouble()
        : 0.0;
    final medicineEncoded = _encodeMedicineType(medicine, purpose: purpose);
    if (medicineEncoded == null) return null;

    return <double>[
      medicineEncoded.toDouble(),
      totalDoses.clamp(0, 100000).toDouble(),
      takenDoses.clamp(0, 100000).toDouble(),
      missedDoses.clamp(0, 100000).toDouble(),
      delayMinutes.clamp(0, 100000).toDouble(),
      normalizedAdherence,
    ];
  }

  String decodeScores(
    List<double> scores, {
    required double fallbackAdherence,
  }) {
    if (scores.length != 3) {
      return _fallbackResult(fallbackAdherence).level;
    }
    final index = _argmax(scores);
    return _scoreIndexToLevel[index] ??
        _fallbackResult(fallbackAdherence).level;
  }

  int? _encodeMedicineType(String medicine, {String? purpose}) {
    final category = _detectCategory(medicine, purpose: purpose);
    if (category == null) return null;
    return _medicineTypeEncoding[category];
  }

  String? _detectCategory(String medicine, {String? purpose}) {
    final combined =
        '${medicine.toLowerCase()} ${(purpose ?? '').toLowerCase()}';
    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (combined.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  int _argmax(List<double> values) {
    var bestIndex = 0;
    var bestValue = values.first;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > bestValue) {
        bestValue = values[i];
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  RiskInferenceResult _fallbackResult(double adherencePercentage) {
    final level = adherencePercentage >= 80
        ? 'LOW'
        : adherencePercentage >= 50
        ? 'MEDIUM'
        : 'HIGH';

    return RiskInferenceResult(
      level: level,
      scores: const <double>[0, 0, 0],
      fallbackUsed: true,
    );
  }
}
