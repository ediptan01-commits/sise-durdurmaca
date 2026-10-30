import 'dart:math' as math;

/// Ekran boyutundan bagimsiz, test edilebilir oyun kurallari.
class GameRules {
  static const double sceneWidth = 390;
  static const double platformTop = 555;
  static const double bottleWidth = 52;
  static const double bottleHeight = 128;
  static const double gravity = 1450;

  static double platformWidth(int level) {
    return math.max(140.0, 280.0 - (level - 1) * 13.0);
  }

  static double platformCenterX(int level) {
    if (level == 1) return sceneWidth / 2;
    return sceneWidth / 2 + math.sin(level * 1.7) * 32;
  }

  static double uprightError(double angleRadians) {
    return math.atan2(math.sin(angleRadians), math.cos(angleRadians)).abs();
  }

  static bool isSuccessfulLanding({
    required double bottleX,
    required double bottleAngle,
    required double horizontalVelocity,
    required double platformCenter,
    required double platformWidth,
  }) {
    const safeInset = bottleWidth * .30;
    const angleTolerance = 0.39; // ~22 derece.
    return (bottleX - platformCenter).abs() <= platformWidth / 2 - safeInset &&
        uprightError(bottleAngle) <= angleTolerance &&
        horizontalVelocity.abs() < 245;
  }

  static double halfVerticalExtent(double radians) {
    return (math.cos(radians).abs() * bottleHeight +
            math.sin(radians).abs() * bottleWidth) /
        2;
  }

  static double clamp(double value, double min, double max) =>
      value.clamp(min, max).toDouble();
}
