import 'package:flutter_test/flutter_test.dart';
import 'package:medidispense/services/risk_inference_service.dart';

void main() {
  final service = RiskInferenceService.instance;

  test('buildModelInput uses confirmed feature order', () {
    final input = service.buildModelInput(
      medicine: 'BP tablet',
      purpose: 'blood pressure',
      totalDoses: 20,
      takenDoses: 15,
      missedDoses: 3,
      delayMinutes: 42,
      adherencePercentage: 75.5,
    );

    expect(input, isNotNull);
    expect(input!.length, 6);
    expect(input[0], 1); // BP encoded
    expect(input[1], 20);
    expect(input[2], 15);
    expect(input[3], 3);
    expect(input[4], 42);
    expect(input[5], 75.5);
  });

  test('decodeScores maps indices to confirmed risk labels', () {
    expect(
      service.decodeScores(const [0.9, 0.05, 0.05], fallbackAdherence: 80),
      'HIGH',
    );
    expect(
      service.decodeScores(const [0.2, 0.7, 0.1], fallbackAdherence: 80),
      'LOW',
    );
    expect(
      service.decodeScores(const [0.1, 0.2, 0.7], fallbackAdherence: 80),
      'MEDIUM',
    );
  });

  test('predictRisk falls back when medicine type cannot be encoded', () {
    final result = service.predictRisk(
      medicine: 'Unknown medicine',
      purpose: 'General health',
      totalDoses: 10,
      takenDoses: 9,
      missedDoses: 1,
      delayMinutes: 5,
      adherencePercentage: 90,
    );

    expect(result.fallbackUsed, isTrue);
    expect(result.level, 'LOW');
  });
}
