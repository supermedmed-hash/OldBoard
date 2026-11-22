import 'package:flutter_test/flutter_test.dart';
import 'package:oldboard/models/engine_data.dart';
import 'package:oldboard/services/dashboard_controller.dart';
import 'package:oldboard/services/settings.dart';
import 'package:oldboard/services/vag_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('decodeSimos21F4 : formules exactes d\'en-tête 0x02 vérifiées sur 06A906019AM', () {
    // Groupe 001 (80 20 | 8C 30 | 85 05 | 88 FF) : ralenti chaud 800 rpm, 95.25°C, sonde O2 0.76V
    final g1 = decodeSimos21F4(1, [25, 191, 39, 130]);
    expect(g1[0].value, closeTo(800.0, 0.01));
    expect(g1[1].value, closeTo(95.25, 0.01));
    expect(g1[2].value, closeTo(0.762, 0.01));
    expect(g1[2].unit, 'V');

    // Groupe 002 (80 20 | 98 D9 | 86 01 | 88 0F) : 800 rpm, 86.8 mg/H (spec ralenti 76-164 mg/H), 0 km/h
    final g2Idle = decodeSimos21F4(2, [25, 16, 0, 4]);
    expect(g2Idle[1].value, closeTo(86.8, 0.5));
    expect(g2Idle[1].unit, 'mg/H');

    // Groupe 003 (80 20 | 98 D9 | 84 01 | 93 64) : papillon 2.0° ralenti / 79.2° WOT, actuateur 0.0% à b3=128
    final g3Idle = decodeSimos21F4(3, [24, 16, 5, 128]);
    expect(g3Idle[1].value, closeTo(13.56, 0.1));
    expect(g3Idle[2].value, closeTo(2.0, 0.01));
    expect(g3Idle[3].value, closeTo(0.0, 0.01));
    final g3Wot = decodeSimos21F4(3, [93, 95, 198, 133]);
    expect(g3Wot[2].value, closeTo(79.2, 0.01));
    expect(g3Wot[3].value, closeTo(3.91, 0.1));

    // Groupe 004 (80 20 | 98 D9 | 89 0A | 96 00) :
    // - Ralenti chaud 832 rpm : b2=36 => 3.60 ms (spec 2.0-4.1 ms), b3=2 => 2.84 g/s (spec 1.8-3.2 g/s)
    final g4Idle = decodeSimos21F4(4, [26, 21, 36, 2]);
    expect(g4Idle[2].value, closeTo(3.60, 0.01));
    expect(g4Idle[2].unit, 'ms');
    expect(g4Idle[3].value, closeTo(2.844, 0.01));
    expect(g4Idle[3].unit, 'g/s');

    // - Moteur coupé (b0=0, b2=12 temps mort 1.20 ms, b3=0) => MAF 0.0 g/s
    final g4Off = decodeSimos21F4(4, [0, 0, 12, 0]);
    expect(g4Off[2].value, closeTo(1.20, 0.01));
    expect(g4Off[3].value, closeTo(0.0, 0.001));

    // - Croisière 83 km/h (b0=78 -> 2496 rpm, b2=58 -> 5.80 ms, b3=11 -> 15.64 g/s)
    final g4Cruise = decodeSimos21F4(4, [78, 35, 58, 11]);
    expect(g4Cruise[2].value, closeTo(5.80, 0.01));
    expect(g4Cruise[3].value, closeTo(15.64, 0.05));

    // Groupe 005 (80 20 | 85 1A | 8C 30 | 8C 30) : tension batterie exacte 140 * 26 / 256 = 14.22 V
    final g5 = decodeSimos21F4(5, [24, 140, 191, 102]);
    expect(g5[1].value, closeTo(14.22, 0.02));
    expect(g5[2].value, closeTo(95.25, 0.02));
    expect(g5[3].value, closeTo(28.5, 0.02));

    // Groupe 007 : b1=131 (+2.34 % régulation lambda)
    final g7 = decodeSimos21F4(7, [5, 131, 128, 4]);
    expect(g7[0].value, closeTo(2.0, 0.01));
    expect(g7[1].value, closeTo(2.34, 0.01));
  });

  test('Conso OEM FIS (temps d\'injection G4:2 + 037906031AA 205 cc/min) vs MAF G4:3 sur essais réels', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final c = DashboardController(s)..isSimosF4 = true;

    // 1. Ralenti chaud 800 rpm (task-373 : b2=29 => 2.90 ms) => ~0.67 L/h
    final g4WarmIdle = decodeSimos21F4(4, [25, 16, 29, 1]);
    c.data.set(EngineRole.rpm, 800);
    c.data.set(EngineRole.speed, 0);
    c.data.set(EngineRole.injection, g4WarmIdle[2].value!);
    c.data.set(EngineRole.maf, g4WarmIdle[3].value!);
    expect(c.computeLph()!, closeTo(0.67, 0.05));

    // 2. Ralenti 832 rpm (task-380 : b2=36 => 3.60 ms, b3=2 => 2.84 g/s) => ~0.94 L/h (identique au MAF 0.93 L/h !)
    final g4Idle = decodeSimos21F4(4, [26, 21, 36, 2]);
    c.data.set(EngineRole.rpm, 832);
    c.data.set(EngineRole.injection, g4Idle[2].value!);
    c.data.set(EngineRole.maf, g4Idle[3].value!);
    expect(c.computeLph()!, closeTo(0.94, 0.05));

    // 3. Croisière 83 km/h (2496 rpm, b2=58 => 5.80 ms, b3=11 => 15.64 g/s) => 5.07 L/h => 6.10 L/100 km
    final g4_83 = decodeSimos21F4(4, [78, 35, 58, 11]);
    c.data.set(EngineRole.rpm, 2496);
    c.data.set(EngineRole.speed, 83);
    c.data.set(EngineRole.injection, g4_83[2].value!);
    c.data.set(EngineRole.maf, g4_83[3].value!);
    final lph83 = c.computeLph()!;
    final l100_83 = lph83 / 83.0 * 100.0;
    expect(lph83, closeTo(5.07, 0.05));
    expect(l100_83, closeTo(6.10, 0.1));

    // 4. Autoroute 140 km/h (4256 rpm, b2=78 => 7.80 ms) => ~12.1 L/h => ~8.66 L/100 km
    final g4_140 = decodeSimos21F4(4, [133, 48, 78, 25]);
    c.data.set(EngineRole.rpm, 4256);
    c.data.set(EngineRole.speed, 140);
    c.data.set(EngineRole.injection, g4_140[2].value!);
    c.data.set(EngineRole.maf, g4_140[3].value!);
    final l100_140 = c.computeLph()! / 140.0 * 100.0;
    expect(l100_140, inInclusiveRange(7.5, 10.5));
  });
}
