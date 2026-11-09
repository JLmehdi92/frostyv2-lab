import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/pinata.dart';

import '../fixtures/pinata_payloads.dart';

void main() {
  test('reads a running piñata', () {
    final pinata = PinataState.fromBody(pinataResponse())!;

    expect(pinata.stage, 2);
    expect(pinata.eligibility, PinataEligibility.yes);
    expect(pinata.expiresAt, DateTime.utc(2026, 11, 9, 20, 5));
  });

  test('signed out, eligibility is unknown and offered as no', () {
    expect(
      PinataState.fromBody(pinataResponse(eligible: null))!.eligibility,
      PinataEligibility.no,
    );
  });

  test('another train, an ended one or none is no piñata', () {
    expect(
      PinataState.fromBody(pinataResponse(typename: 'MythicTrainDetails')),
      isNull,
    );
    expect(PinataState.fromBody(pinataResponse(active: false)), isNull);
    expect(PinataState.fromBody(noPinataResponse), isNull);
    expect(PinataState.fromBody(null), isNull);
  });
}
