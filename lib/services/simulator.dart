import 'dart:math' as math;

import '../models/engine_data.dart';

/// Simulateur de conduite d'une A3 8L 1.6 AKL (pour tester sans la voiture).
class Simulator {
  final _rnd = math.Random();

  /// km/h pour 1000 tr/min sur chaque rapport (BV5, 195/65 R15, approx.)
  static const kmhPer1000 = [0.0, 8.1, 13.2, 19.6, 27.2, 33.4];

  static const _plan = <(double, double)>[
    (0, 6), (50, 22), (90, 28), (130, 25), (70, 18), (0, 12), (110, 28), (30, 15),
  ];

  int _phase = 0;
  double _phaseT = 0;
  double speed = 0;
  double coolant = 18;
  double iat = 22;
  int gear = 1;
  double throttle = 0;

  void reset() {
    _phase = 0;
    _phaseT = 0;
    speed = 0;
    gear = 1;
    coolant = 18;
  }

  void step(double dt, EngineData d) {
    _phaseT += dt;
    if (_phaseT > _plan[_phase].$2) {
      _phaseT = 0;
      _phase = (_phase + 1) % _plan.length;
    }
    final target = _plan[_phase].$1;
    final diff = target - speed;

    if (diff > 2) {
      final a = switch (gear) { 1 => 2.6, 2 => 2.2, 3 => 1.6, 4 => 1.1, _ => 0.7 }; // m/s²
      speed += a * 3.6 * dt;
      throttle = 0.55 + 0.35 * math.min(1, diff / 40);
    } else if (diff < -2) {
      speed -= 2.2 * 3.6 * dt;
      throttle = 0;
    } else {
      speed += diff * 0.5 * dt;
      throttle = 0.08 + speed / 450;
    }
    speed = math.max(0, speed);

    // boite de vitesses
    double rpmFor(int g) => speed / kmhPer1000[g] * 1000;
    final up = diff > 2 ? 3200 : 2400;
    if (gear < 5 && rpmFor(gear) > up) gear++;
    if (gear > 1 && rpmFor(gear) < 1300) gear--;

    double rpm;
    if (speed < 6 && diff <= 2) {
      rpm = 820 + _rnd.nextDouble() * 30; // ralenti (debraye)
      throttle = 0;
      if (speed < 1) gear = 1;
    } else {
      rpm = math.max(900, rpmFor(gear));
    }

    // injection : coupure en deceleration
    double inj;
    if (throttle == 0 && rpm > 1300) {
      inj = 0;
    } else if (throttle == 0) {
      inj = 2.5 + (coolant < 60 ? 0.7 : 0);
    } else {
      inj = 2.5 + throttle * 11.0 + (coolant < 60 ? 0.7 : 0);
    }

    coolant += (90 - coolant) * dt / 70;
    iat += ((speed > 30 ? 18 : 32) - iat) * dt / 40;

    d.set(EngineRole.rpm, rpm);
    d.set(EngineRole.speed, speed);
    d.set(EngineRole.injection, inj);
    d.set(EngineRole.coolant, coolant);
    d.set(EngineRole.intakeAir, iat);
    d.set(EngineRole.battery, 14.0 + _rnd.nextDouble() * 0.15);
    d.set(EngineRole.map, 980 + throttle * 1150);
    d.set(EngineRole.maf, throttle == 0 && rpm > 1300 ? 2.0 : (3.0 + throttle * 75.0));
    d.set(EngineRole.fuelMg, throttle == 0 && rpm > 1300 ? 0.0 : (4.2 + throttle * 38.0));
    d.set(EngineRole.throttle, throttle * 84);
    d.set(EngineRole.load, (18.0 + throttle * 78.0).clamp(0.0, 100.0));
    // Régulation lambda Simos 2 (oscillation normale entre -3 % et +3 % autour de 0 %)
    final lambdaOsc = math.sin(_phaseT * 2.4) * 2.8 + (_rnd.nextDouble() - 0.5) * 0.8;
    d.set(EngineRole.lambda, throttle == 0 && rpm > 1300 ? 0.0 : lambdaOsc);
  }
}
