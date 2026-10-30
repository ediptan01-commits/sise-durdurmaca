import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game_logic.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SiseDurdurmacaApp());
}

class SiseDurdurmacaApp extends StatelessWidget {
  const SiseDurdurmacaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Şişe Durdurmaca',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF136D80),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFEAF6FA),
        ),
        home: const BottleGameScreen(),
      );
}

enum RoundPhase { ready, flying, success, failed }

class BottleGameScreen extends StatefulWidget {
  const BottleGameScreen({super.key});

  @override
  State<BottleGameScreen> createState() => _BottleGameScreenState();
}

class _BottleGameScreenState extends State<BottleGameScreen>
    with SingleTickerProviderStateMixin {
  static const double _sceneHeight = 680;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _nextRoundTimer;

  RoundPhase _phase = RoundPhase.ready;
  double _bottleX = GameRules.sceneWidth / 2;
  double _bottleY = GameRules.platformTop - GameRules.bottleHeight / 2;
  double _angle = 0;
  double _velocityX = 0;
  double _velocityY = 0;
  double _angularSpeed = 0;
  double _dragX = 0;
  double _dragY = 0;
  double _gestureScaleX = 1;
  double _gestureScaleY = 1;

  int _level = 1;
  int _score = 0;
  int _bestScore = 0;
  int _streak = 0;
  int _attempts = 0;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _nextRoundTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_phase != RoundPhase.flying) return;
    final timeStep = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    if (timeStep <= 0) return;
    final dt = math.min(timeStep, 0.045);

    final nextX = _bottleX + _velocityX * dt;
    final nextY = _bottleY + _velocityY * dt;
    final nextAngle = _angle + _angularSpeed * dt;
    final nextVerticalVelocity = _velocityY + GameRules.gravity * dt;

    final bottleBottom = nextY + GameRules.halfVerticalExtent(nextAngle);
    final landing = nextVerticalVelocity >= 0 &&
        bottleBottom >= GameRules.platformTop;

    if (landing) {
      _ticker.stop();
      final hit = GameRules.isSuccessfulLanding(
        bottleX: nextX,
        bottleAngle: nextAngle,
        horizontalVelocity: _velocityX,
        platformCenter: GameRules.platformCenterX(_level),
        platformWidth: GameRules.platformWidth(_level),
      );
      if (hit) {
        _completeLanding(nextX);
      } else {
        _failLanding(nextX, nextAngle);
      }
      return;
    }

    if (nextY > _sceneHeight + 80 || nextX < -90 || nextX > 480) {
      _ticker.stop();
      _failLanding(nextX.clamp(24.0, 366.0).toDouble(), nextAngle);
      return;
    }

    setState(() {
      _bottleX = nextX;
      _bottleY = nextY;
      _angle = nextAngle;
      _velocityY = nextVerticalVelocity;
    });
  }

  void _completeLanding(double x) {
    if (_soundEnabled) SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = RoundPhase.success;
      _bottleX = x;
      _bottleY = GameRules.platformTop - GameRules.bottleHeight / 2;
      _angle = 0;
      _streak++;
      _score += 10 + (_streak - 1) * 5;
      _bestScore = math.max(_bestScore, _score);
    });
    _nextRoundTimer?.cancel();
    _nextRoundTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _level++;
        _resetBottle();
      });
    });
  }

  void _failLanding(double x, double angle) {
    HapticFeedback.lightImpact();
    setState(() {
      _phase = RoundPhase.failed;
      _bottleX = x;
      _angle = angle;
      _bottleY = GameRules.platformTop - GameRules.halfVerticalExtent(angle);
      _streak = 0;
    });
  }

  void _resetBottle() {
    _ticker.stop();
    _phase = RoundPhase.ready;
    _bottleX = GameRules.sceneWidth / 2;
    _bottleY = GameRules.platformTop - GameRules.bottleHeight / 2;
    _angle = 0;
    _velocityX = 0;
    _velocityY = 0;
    _angularSpeed = 0;
    _dragX = 0;
    _dragY = 0;
  }

  void _onPanStart(DragStartDetails details) {
    if (_phase != RoundPhase.ready) return;
    _dragX = 0;
    _dragY = 0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase != RoundPhase.ready) return;
    _dragX += details.delta.dx * _gestureScaleX;
    _dragY += details.delta.dy * _gestureScaleY;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_phase != RoundPhase.ready) return;
    final upwardDistance = -_dragY;
    if (upwardDistance < 42) return;

    final speedUp = math.max(0.0,
        -details.velocity.pixelsPerSecond.dy * _gestureScaleY);
    final sideways =
        details.velocity.pixelsPerSecond.dx * _gestureScaleX;

    // Yukari kaydirma yuksekligi ve hizinin ikisi de fizik sonucunu etkiler.
    final throwSpeed = GameRules.clamp(
      480 + upwardDistance * 1.35 + speedUp * 0.06,
      550,
      900,
    );
    final spinSpeed = GameRules.clamp(
      3.2 + upwardDistance * 0.010 + speedUp * 0.0015,
      3.6,
      11.8,
    );
    final horizontalSpeed = GameRules.clamp(
      _dragX * 1.85 + sideways * 0.04,
      -235,
      235,
    );

    _nextRoundTimer?.cancel();
    _lastTick = Duration.zero;
    setState(() {
      _attempts++;
      _phase = RoundPhase.flying;
      _velocityY = -throwSpeed;
      _velocityX = horizontalSpeed;
      _angularSpeed = spinSpeed;
    });
    _ticker.start();
  }

  void _retry() {
    HapticFeedback.selectionClick();
    setState(_resetBottle);
  }

  void _restartGame() {
    _nextRoundTimer?.cancel();
    setState(() {
      _level = 1;
      _score = 0;
      _streak = 0;
      _attempts = 0;
      _resetBottle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _gestureScaleX = GameRules.sceneWidth / constraints.maxWidth;
          _gestureScaleY = _sceneHeight / constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _GamePainter(
                  bottleX: _bottleX,
                  bottleY: _bottleY,
                  angle: _angle,
                  level: _level,
                  phase: _phase,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: const SizedBox.expand(),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 13, 18, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ŞİŞE',
                                    style: TextStyle(
                                      color: Color(0xFF0D5665),
                                      fontSize: 27,
                                      fontWeight: FontWeight.w900,
                                      height: 0.95,
                                      letterSpacing: 1.4,
                                    )),
                                Text('DURDURMACA',
                                    style: TextStyle(
                                      color: Color(0xFF166F7F),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.1,
                                    )),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: _soundEnabled ? 'Sesi kapat' : 'Sesi aç',
                            onPressed: () =>
                                setState(() => _soundEnabled = !_soundEnabled),
                            icon: Icon(_soundEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            tooltip: 'Oyunu sıfırla',
                            onPressed: _restartGame,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                              child: _StatPill(
                                  title: 'BÖLÜM',
                                  value: '$_level',
                                  icon: Icons.flag_rounded)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _StatPill(
                                  title: 'PUAN',
                                  value: '$_score',
                                  icon: Icons.stars_rounded)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _StatPill(
                                  title: 'SERİ',
                                  value: '$_streak',
                                  icon: Icons.local_fire_department_rounded)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_phase == RoundPhase.success)
                const Positioned(
                  left: 18,
                  right: 18,
                  top: 210,
                  child: _ResultBanner(
                    title: 'MÜKEMMEL ATIŞ! 🎉',
                    subtitle: 'Şişe ayakta! Sonraki bölüm geliyor.',
                    success: true,
                  ),
                ),
              if (_phase == RoundPhase.failed)
                Positioned(
                  left: 28,
                  right: 28,
                  top: constraints.maxHeight * .31,
                  child: Column(
                    children: [
                      const _ResultBanner(
                        title: 'AZ KALDI!',
                        subtitle: 'Şişe dik durmadı. Bir daha dene.',
                        success: false,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('TEKRAR DENE'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 15),
                          backgroundColor: const Color(0xFF0D6474),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
                child: IgnorePointer(
                  child: _InstructionPill(
                    phase: _phase,
                    bestScore: _bestScore,
                    attempts: _attempts,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFB9DCE1)),
          boxShadow: const [
            BoxShadow(color: Color(0x160B6276), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: const Color(0xFF278D98)),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5A8490),
                          letterSpacing: .7)),
                  Text(value,
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF124E5C))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.title,
    required this.subtitle,
    required this.success,
  });

  final String title;
  final String subtitle;
  final bool success;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: success ? const Color(0xFFF0FFEA) : const Color(0xFFFFF5E2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: success
                  ? const Color(0xFF8CD88F)
                  : const Color(0xFFEFCB83),
              width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x250E5361), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: success
                        ? const Color(0xFF247039)
                        : const Color(0xFF8A5816))),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF586268), fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _InstructionPill extends StatelessWidget {
  const _InstructionPill({
    required this.phase,
    required this.bestScore,
    required this.attempts,
  });

  final RoundPhase phase;
  final int bestScore;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    final String message;
    switch (phase) {
      case RoundPhase.ready:
        message = '👆 Parmağını yukarı kaydır, şişeyi çevir!';
      case RoundPhase.flying:
        message = '🌀 Dönüyor... Dik durabilecek mi?';
      case RoundPhase.success:
        message = '⭐ Harika! Yeni hedef hazırlanıyor.';
      case RoundPhase.failed:
        message = '💡 Fırlatma hızını değiştirerek tekrar dene.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF073E4B).withValues(alpha: .93),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x22043745), blurRadius: 18, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(height: 5),
          Text('En iyi: $bestScore  •  Toplam atış: $attempts',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFACDADD),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter({
    required this.bottleX,
    required this.bottleY,
    required this.angle,
    required this.level,
    required this.phase,
  });

  final double bottleX;
  final double bottleY;
  final double angle;
  final int level;
  final RoundPhase phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / GameRules.sceneWidth, size.height / 680);
    _background(canvas);
    _platform(canvas);
    _targetIndicator(canvas);
    _bottleShadow(canvas);
    _bottle(canvas);
    canvas.restore();
  }

  void _background(Canvas canvas) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD9F3F9), Color(0xFFF7F5E8), Color(0xFFFFEBD0)],
        stops: [0.0, .60, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 390, 680));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 390, 680), sky);

    // Hafif dekoratif bulutlar.
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: .48);
    for (final cloud in const [
      Offset(36, 182),
      Offset(315, 257),
      Offset(80, 335),
    ]) {
      canvas.drawOval(Rect.fromCenter(center: cloud, width: 110, height: 24), cloudPaint);
      canvas.drawCircle(cloud.translate(-18, -7), 18, cloudPaint);
      canvas.drawCircle(cloud.translate(18, -10), 25, cloudPaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFFB9D8D6).withValues(alpha: .40)
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final y = 375.0 + i * 31.0;
      canvas.drawLine(Offset(0, y), Offset(390, y), linePaint);
    }

    // Zeminin yumusak renk gecisi.
    final floor = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEBCDA6), Color(0xFFD6A578)],
      ).createShader(const Rect.fromLTWH(0, 575, 390, 105));
    canvas.drawRect(const Rect.fromLTWH(0, 575, 390, 105), floor);
    canvas.drawLine(const Offset(0, 577), const Offset(390, 577),
        Paint()..color = const Color(0xFFD2A577)..strokeWidth = 3);
  }

  void _platform(Canvas canvas) {
    final center = GameRules.platformCenterX(level);
    final width = GameRules.platformWidth(level);
    final top = GameRules.platformTop;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(center - width / 2, top, width, 24),
      const Radius.circular(10),
    );
    canvas.drawRRect(
        rect.shift(const Offset(0, 7)),
        Paint()
          ..color = const Color(0xFF623D24).withValues(alpha: .20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE5AA70), Color(0xFF9D623D)],
        ).createShader(rect.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center - width / 2, top, width, 7),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFF5D09B),
    );
    canvas.drawLine(Offset(center - width / 2 + 11, top + 15),
        Offset(center + width / 2 - 11, top + 15),
        Paint()..color = const Color(0xFF8E5338).withValues(alpha: .40));
  }

  void _targetIndicator(Canvas canvas) {
    if (phase == RoundPhase.flying) return;
    final center = GameRules.platformCenterX(level);
    final width = GameRules.platformWidth(level);
    final x = center - width / 2 + 14;
    final path = Path()
      ..moveTo(x, GameRules.platformTop - 10)
      ..lineTo(x + 7, GameRules.platformTop - 24)
      ..lineTo(x + 14, GameRules.platformTop - 10)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF2A8C82).withValues(alpha: .72));
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'HEDEF',
        style: TextStyle(
          color: Color(0xFF247B80),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(center - textPainter.width / 2, 574));
  }

  void _bottleShadow(Canvas canvas) {
    final dist = (GameRules.platformTop -
            (bottleY + GameRules.halfVerticalExtent(angle)))
        .clamp(0.0, 400.0);
    final t = 1 - dist / 490;
    final shadowPaint = Paint()
      ..color = const Color(0xFF163A47).withValues(alpha: .20 * t)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bottleX, GameRules.platformTop - 1),
          width: 62 + dist * .1,
          height: 13 + dist * .015),
      shadowPaint,
    );
  }

  void _bottle(Canvas canvas) {
    canvas.save();
    canvas.translate(bottleX, bottleY);
    canvas.rotate(angle);

    final bottleShape = Path()
      ..moveTo(-17, -64)
      ..lineTo(17, -64)
      ..lineTo(17, -49)
      ..cubicTo(17, -40, 25, -38, 25, -28)
      ..lineTo(26, 51)
      ..quadraticBezierTo(25, 64, 13, 64)
      ..lineTo(-13, 64)
      ..quadraticBezierTo(-25, 64, -26, 51)
      ..lineTo(-25, -28)
      ..cubicTo(-25, -38, -17, -40, -17, -49)
      ..close();

    canvas.drawPath(
        bottleShape,
        Paint()
          ..color = const Color(0xFF5E9CAC).withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawPath(
      bottleShape,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB4E6F3), Color(0xFFF1FBFF), Color(0xFF7CCAD9)],
          stops: [.0, .46, 1.0],
        ).createShader(const Rect.fromLTWH(-27, -64, 54, 128)),
    );

    canvas.save();
    canvas.clipPath(bottleShape);
    final waterPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6BD6EE), Color(0xFF238AB7)],
      ).createShader(const Rect.fromLTWH(-26, 7, 52, 60));
    final waterPath = Path()
      ..moveTo(-26, 7)
      ..quadraticBezierTo(-13, 2, 0, 7)
      ..quadraticBezierTo(14, 13, 26, 6)
      ..lineTo(26, 66)
      ..lineTo(-26, 66)
      ..close();
    canvas.drawPath(waterPath, waterPaint);
    canvas.restore();

    canvas.drawPath(
      bottleShape,
      Paint()
        ..color = const Color(0xFF4596A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-19, -70, 38, 13),
          const Radius.circular(4)),
      Paint()..color = const Color(0xFF137C9A),
    );
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(Offset(-15 + i * 6, -69), Offset(-15 + i * 6, -59),
          Paint()..color = const Color(0xFF76CADE)..strokeWidth = 1);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-26, -15, 52, 33),
          const Radius.circular(4)),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .91),
    );
    canvas.drawRect(const Rect.fromLTWH(-26, -12, 52, 4),
        Paint()..color = const Color(0xFFE8AE57));
    canvas.drawRect(const Rect.fromLTWH(-26, 12, 52, 4),
        Paint()..color = const Color(0xFFE8AE57));
    final label = TextPainter(
      text: const TextSpan(
        text: 'FLIP',
        style: TextStyle(
          color: Color(0xFF197A91),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(-label.width / 2, -7));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-17, 22, 5, 33),
          const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: .40),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) =>
      bottleX != old.bottleX ||
      bottleY != old.bottleY ||
      angle != old.angle ||
      level != old.level ||
      phase != old.phase;
}
