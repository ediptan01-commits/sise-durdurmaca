import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sise_durdurmaca/game_logic.dart';

void main() {
  group('Sise Durdurmaca oyun kurallari', () {
    test('Tam bir tur dik inis kabul edilir', () {
      expect(
        GameRules.isSuccessfulLanding(
          bottleX: 195,
          bottleAngle: 2 * math.pi,
          horizontalVelocity: 0,
          platformCenter: 195,
          platformWidth: 200,
        ),
        isTrue,
      );
    });

    test('Yatay sise basarisiz sayilir', () {
      expect(
        GameRules.isSuccessfulLanding(
          bottleX: 195,
          bottleAngle: math.pi / 2,
          horizontalVelocity: 0,
          platformCenter: 195,
          platformWidth: 200,
        ),
        isFalse,
      );
    });

    test('Ters duran sise basarisiz sayilir', () {
      expect(
        GameRules.isSuccessfulLanding(
          bottleX: 195,
          bottleAngle: math.pi,
          horizontalVelocity: 0,
          platformCenter: 195,
          platformWidth: 200,
        ),
        isFalse,
      );
    });

    test('Platform disina inis basarisizdir', () {
      expect(
        GameRules.isSuccessfulLanding(
          bottleX: 355,
          bottleAngle: 0,
          horizontalVelocity: 0,
          platformCenter: 195,
          platformWidth: 200,
        ),
        isFalse,
      );
    });

    test('Platform asamali daralir ancak 140 altina inmez', () {
      expect(GameRules.platformWidth(1), 280);
      expect(GameRules.platformWidth(2), lessThan(280));
      expect(GameRules.platformWidth(100), 140);
    });

    test('Sisenin dik ve yatay yukseklikleri dogrudur', () {
      expect(GameRules.halfVerticalExtent(0), 64);
      expect(GameRules.halfVerticalExtent(math.pi / 2), closeTo(26, .0001));
    });
  });
}
