import 'package:flutter_test/flutter_test.dart';
import 'package:oldboard/models/engine_data.dart';
import 'package:oldboard/services/dashboard_controller.dart';
import 'package:oldboard/services/settings.dart';
import 'package:oldboard/services/vag_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('decodeSimos21F4 : calibrage réel Audi A3 8L 1.6 AKL (06A906019AM)', () {
    // Groupe 001 : b0=0 (0 rpm), b1=180 (87.0 °C), b2=10 (0.05 V sonde O2), b3=0x00
    final g1 = decodeSimos21F4(1, [0, 180, 10, 0]);
    expect(g1[0].value, closeTo(0.0, 0.01));
    expect(g1[1].value, closeTo(87.0, 0.01));
    expect(g1[2].value, closeTo(0.05, 0.001));
    expect(g1[2].unit, 'V');

    // Groupe 003 : b2=7 (2.8° ralenti), b3=128 (0.0° avance moteur coupé)
    final g3Idle = decodeSimos21F4(3, [26, 20, 7, 128]);
    expect(g3Idle[2].value, closeTo(2.8, 0.01));
    expect(g3Idle[2].unit, '°');
    expect(g3Idle[3].value, closeTo(0.0, 0.01));
    expect(g3Idle[3].unit, '°');

    // Groupe 003 pleine charge : b2=198 (79.2° pied au plancher)
    final g3Wot = decodeSimos21F4(3, [93, 95, 198, 152]);
    expect(g3Wot[2].value, closeTo(79.2, 0.01));
    expect(g3Wot[3].value, closeTo(18.0, 0.01));

    // Groupe 004 : b2 = masse d'air par coup (3.15 mg/coup/LSB) -> MAF (g/s) = b2 * 3.15 * (rpm / 30000)
    // Moteur coupé (b0=0, b2=12) => 0.0 g/s (plus d'offset fantôme à l'arrêt)
    final g4Off = decodeSimos21F4(4, [0, 0, 12, 0]);
    expect(g4Off[2].value, closeTo(0.0, 0.001));

    // Croisière 83 km/h (b0=78 -> 2496 tr/min, b2=58) => 15.20 g/s
    final g4Cruise = decodeSimos21F4(4, [78, 35, 58, 11]);
    expect(g4Cruise[2].value, closeTo(15.20, 0.05));
    expect(g4Cruise[2].unit, 'g/s');

    // Pleine charge 4928 tr/min (b0=154, b2=165) => 85.38 g/s (cohérent 1.6 101 ch)
    final g4Wot = decodeSimos21F4(4, [154, 95, 165, 11]);
    expect(g4Wot[2].value, closeTo(85.38, 0.1));

    // Groupe 007 : b1=131 (+2.34 % régulation lambda)
    final g7 = decodeSimos21F4(7, [0, 131, 128, 0]);
    expect(g7[1].value, closeTo(2.34, 0.01));
    expect(g7[1].unit, '%');
  });

  test('Consommation instantanée sur instantanés réels 83 km/h et 140 km/h', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final c = DashboardController(s);

    // 1. Croisière 83 km/h (2496 tr/min, b2=58, lambda=+2.34%) => ~6.16 L/100 km
    final g4_83 = decodeSimos21F4(4, [78, 35, 58, 11]);
    final g7 = decodeSimos21F4(7, [44, 131, 128, 2]);
    c.data.set(EngineRole.rpm, 2496);
    c.data.set(EngineRole.speed, 83);
    c.data.set(EngineRole.maf, g4_83[2].value!);
    c.data.set(EngineRole.lambda, g7[1].value!);

    final lph83 = c.computeLph()!;
    final l100_83 = lph83 / 83.0 * 100.0;
    expect(lph83, closeTo(5.12, 0.05));
    expect(l100_83, inInclusiveRange(5.8, 7.0));

    // 2. Autoroute 140 km/h (b0=133 -> 4256 tr/min, b2=78) => ~8.4 L/100 km (cohérent 1.6 AKL à 140)
    final g4_140 = decodeSimos21F4(4, [133, 52, 78, 11]);
    c.data.set(EngineRole.rpm, 4256);
    c.data.set(EngineRole.speed, 140);
    c.data.set(EngineRole.maf, g4_140[2].value!);
    final lph140 = c.computeLph()!;
    final l100_140 = lph140 / 140.0 * 100.0;
    expect(l100_140, inInclusiveRange(7.5, 10.5));
  });
}
