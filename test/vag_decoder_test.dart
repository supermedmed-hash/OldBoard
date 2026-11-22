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

    // Groupe 004 : b2=58 (58 kg/h = 16.11 g/s à 83 km/h), b2=169 (46.94 g/s à 3040 tr/min)
    final g4Cruise = decodeSimos21F4(4, [78, 35, 58, 11]);
    expect(g4Cruise[2].value, closeTo(16.11, 0.02));
    expect(g4Cruise[2].unit, 'g/s');
    final g4Peak = decodeSimos21F4(4, [95, 65, 169, 11]);
    expect(g4Peak[2].value, closeTo(46.94, 0.02));

    // Groupe 007 : b1=131 (+2.34 % régulation lambda)
    final g7 = decodeSimos21F4(7, [0, 131, 128, 0]);
    expect(g7[1].value, closeTo(2.34, 0.01));
    expect(g7[1].unit, '%');
  });

  test('Consommation instantanée sur instantané réel 83 km/h (2496 tr/min, b2=58, lambda=+2.34%)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.load();
    final c = DashboardController(s);

    final g4 = decodeSimos21F4(4, [78, 35, 58, 11]);
    final g7 = decodeSimos21F4(7, [44, 131, 128, 2]);
    c.data.set(EngineRole.rpm, 2496);
    c.data.set(EngineRole.speed, 83);
    c.data.set(EngineRole.maf, g4[2].value!);
    c.data.set(EngineRole.lambda, g7[1].value!);
    c.data.set(EngineRole.injection, 7.595);

    final lph = c.computeLph()!;
    final l100 = lph / 83.0 * 100.0;
    expect(lph, closeTo(5.42, 0.05));
    expect(l100, inInclusiveRange(6.0, 7.5));
    expect(l100, closeTo(6.53, 0.05));
  });
}
