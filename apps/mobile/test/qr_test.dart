import 'package:flutter_test/flutter_test.dart';
import 'package:yusmus_mobile/features/qr/qr_repository.dart';

void main() {
  group('classifyQr (M2 §10-13): pure, camera-free classification of a resolved QR', () {
    test('a WORKER payload with a worker object classifies as worker', () {
      expect(classifyQr({'type': 'WORKER', 'worker': {'id': 'w1'}}), QrOutcomeType.worker);
    });

    test('a KIT payload with a kit object classifies as kit', () {
      expect(classifyQr({'type': 'KIT', 'kit': {'kitTemplateId': 't1'}}), QrOutcomeType.kit);
    });

    test('an unknown type, or a type without its matching object, is never trusted — always invalid', () {
      expect(classifyQr({'type': 'ASSIGNMENT'}), QrOutcomeType.invalid);
      expect(classifyQr({'type': 'WORKER'}), QrOutcomeType.invalid); // missing "worker" — malformed, never guessed
      expect(classifyQr({'type': 'KIT'}), QrOutcomeType.invalid);
      expect(classifyQr({}), QrOutcomeType.invalid);
    });
  });
}
