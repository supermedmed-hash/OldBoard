import 'dart:math' as math;

/// Valeur decodee d'un champ de bloc de mesures VAG (triplet 0xE7 ou octet brut 0xF4 Simos 2.1).
class VagValue {
  final int formula, a, b;
  final double? value;
  final String unit;
  final String? text;

  const VagValue(this.formula, this.a, this.b, this.value, this.unit, [this.text]);

  String get display {
    if (text != null) return text!;
    final v = value;
    if (v == null) return '$a/$b';
    final digits = v.abs() >= 100 ? 0 : (v.abs() >= 10 ? 1 : 2);
    return '${v.toStringAsFixed(digits)} $unit'.trim();
  }
}

/// Formate les 4 octets bruts d'une trame 0xF4 Simos 2.1 pour l'ecran DIAG et le rapport.
String formatF4Raw(List<int> raw) {
  final items = <String>[];
  for (var i = 0; i < raw.length; i++) {
    final b = raw[i] & 0xFF;
    final hex = b.toRadixString(16).padLeft(2, '0').toUpperCase();
    items.add('b$i=$b (0x$hex)');
  }
  return 'F4 raw: [${items.join(", ")}]';
}

/// Decodeur dedie Simos 2.1 (Audi A3 8L 1.6 AKL - 06A906019AM) pour les blocs 0xF4 de 4 octets [b0, b1, b2, b3].
List<VagValue> decodeSimos21F4(int group, List<int> raw) {
  VagValue cell(int idx, double? val, String unit, [String? txt]) {
    final b = idx < raw.length ? (raw[idx] & 0xFF) : 0;
    return VagValue(0xF4, idx, b, val, unit, txt);
  }

  if (raw.length < 4) {
    return [
      for (var i = 0; i < raw.length; i++)
        cell(i, raw[i].toDouble(), '', 'b$i=${raw[i]} (0x${raw[i].toRadixString(16).padLeft(2, '0').toUpperCase()})'),
    ];
  }

  final b0 = raw[0] & 0xFF;
  final b1 = raw[1] & 0xFF;
  final b2 = raw[2] & 0xFF;
  final b3 = raw[3] & 0xFF;

  switch (group) {
    case 1:
      // En-tete 0x02 reel 06A906019AM : 80 20 00 | 8C 30 11 ... | 85 05 00 | 88 FF 00
      // b0 = Regime (b0 * 32 tr/min), b1 = Temp. eau G62 (b1 * 0.75 - 48 °C),
      // b2 = Tension sonde Lambda G39 (b2 * 5 / 256 V), b3 = Bits etat reglage de base
      return [
        cell(0, b0 * 32.0, 'tr/min'),
        cell(1, (b1 * 0.75) - 48.0, '°C'),
        cell(2, b2 * (5.0 / 256.0), 'V'),
        cell(3, b3.toDouble(), '', b3.toRadixString(2).padLeft(8, '0')),
      ];
    case 2:
      // En-tete 0x02 reel : 80 20 00 | 98 D9 00 | 86 01 00 | 88 0F 00
      // b0 = Regime (b0 * 32 tr/min), b1 = Charge / masse d'air par cycle (b1 * 5.425 mg/H, spec ralenti 76-164 mg/H),
      // b2 = Vitesse (b2 * 1 km/h), b3 = Mode (0x04=Ralenti, 0x02=Charge, 0x08=Coupure, 0x01=Pleine charge)
      final modeTxt = switch (b3) {
        0x04 => 'Ralenti (0x04)',
        0x02 => 'Charge (0x02)',
        0x08 => 'Coupure (0x08)',
        0x01 => 'Pleine ch. (0x01)',
        _ => '0x${b3.toRadixString(16).padLeft(2, '0').toUpperCase()}',
      };
      return [
        cell(0, b0 * 32.0, 'tr/min'),
        cell(1, b1 * 5.425, 'mg/H'),
        cell(2, b2 * 1.0, 'km/h'),
        cell(3, b3.toDouble(), '', modeTxt),
      ];
    case 3:
      // En-tete 0x02 reel : 80 20 00 | 98 D9 00 | 84 01 00 | 93 64 11 [0..200]
      // b0 = Regime (tr/min), b1 = Charge moteur (b1 * 217/256 %), b2 = Angle papillon (b2 * 0.4 °),
      // b3 = Actuateur ralenti (-100..+100 % : b3 * 200/256 - 100)
      return [
        cell(0, b0 * 32.0, 'tr/min'),
        cell(1, b1 * (217.0 / 256.0), '%'),
        cell(2, b2 * 0.4, '°'),
        cell(3, (b3 * 200.0 / 256.0) - 100.0, '%'),
      ];
    case 4:
      // En-tete 0x02 reel : 80 20 00 | 98 D9 00 | 89 0A 00 | 96 00 00
      // Manuel atelier VAG Simos 2.1 (06A-906-019) Groupe 004 :
      // b0 = Regime (tr/min), b1 = Charge / air par cycle (mg/H),
      // b2 = Temps d'injection reel (b2 * 0.1 ms — spec ralenti 2.0-4.1 ms, 1.20 ms temps mort moteur coupe),
      // b3 = Debitmetre d'air MAF G70 (b3 * 1.422 g/s — spec ralenti 1.8-3.2 g/s, 15.6 g/s a 83 km/h)
      return [
        cell(0, b0 * 32.0, 'tr/min'),
        cell(1, b1 * 5.425, 'mg/H'),
        cell(2, b2 * 0.1, 'ms'),
        cell(3, b0 == 0 ? 0.0 : b3 * 1.422, 'g/s'),
      ];
    case 5:
      // En-tete 0x02 reel : 80 20 00 | 85 1A 00 | 8C 30 11 ... | 8C 30 11 ...
      // b0 = Regime (tr/min), b1 = Tension batterie exacte (b1 * 26/256 V : 140 -> 14.22 V),
      // b2 = Temp. eau G62 (°C), b3 = Temp. air admission G42 (°C)
      return [
        cell(0, b0 * 32.0, 'tr/min'),
        cell(1, b1 * (26.0 / 256.0), 'V'),
        cell(2, (b2 * 0.75) - 48.0, '°C'),
        cell(3, (b3 * 0.75) - 48.0, '°C'),
      ];
    case 7:
      // En-tete 0x02 reel : 84 01 00 | 92 27 00 | 92 27 00 | 88 0F 00
      // b0 = Angle papillon (b0 * 0.4 °), b1 = Regulation lambda ((b1-128)*0.78 %), b2 = Adaptation lambda (%), b3 = Mode
      return [
        cell(0, b0 * 0.4, '°'),
        cell(1, (b1 - 128) * 0.78, '%'),
        cell(2, (b2 - 128) * 0.78, '%'),
        cell(3, b3.toDouble(), '', '0x${b3.toRadixString(16).padLeft(2, '0').toUpperCase()}'),
      ];
    default:
      return [
        for (var i = 0; i < raw.length; i++)
          cell(i, raw[i].toDouble(), '', 'b$i=${raw[i]} (0x${raw[i].toRadixString(16).padLeft(2, '0').toUpperCase()})'),
      ];
  }
}

/// Table des formules KWP1281 (0xE7) les plus courantes.
VagValue decodeVag(int f, int a, int b) {
  VagValue v(double x, String u) => VagValue(f, a, b, x, u);
  switch (f) {
    case 0x01: return v(0.2 * a * b, 'tr/min');
    case 0x02: return v(a * 0.002 * b, '%');
    case 0x03: return v(0.002 * a * b, '°');
    case 0x04: return v((b - 127) * 0.01 * a, '°');
    case 0x05: return v(a * (b - 100) * 0.1, '°C');
    case 0x06: return v(0.001 * a * b, 'V');
    case 0x07: return v(0.01 * a * b, 'km/h');
    case 0x08: return v(0.1 * a * b, '');
    case 0x09: return v((b - 127) * 0.02 * a, '°');
    case 0x0A: return VagValue(f, a, b, b.toDouble(), '', b == 0 ? 'Froid' : 'Chaud');
    case 0x0B: return v(0.0001 * a * (b - 128) + 1, 'λ');
    case 0x0C: return v(0.001 * a * b, 'Ω');
    case 0x0D: return v((b - 127) * 0.001 * a, 'mm');
    case 0x0E: return v(0.005 * a * b, 'bar');
    case 0x0F: return v(0.01 * a * b, 'ms');
    case 0x10:
      final bits = (a & b).toRadixString(2).padLeft(8, '0');
      return VagValue(f, a, b, null, '', bits);
    case 0x11:
      return VagValue(f, a, b, null, '', String.fromCharCodes([a, b].where((c) => c >= 32 && c < 127)));
    case 0x12: return v(0.04 * a * b, 'mbar');
    case 0x13: return v(a * b * 0.01, 'L');
    case 0x14: return v(a * (b - 128) / 128, '%');
    case 0x15: return v(0.001 * a * b, 'V');
    case 0x16: return v(0.001 * a * b, 'ms');
    case 0x17: return v(b / 256 * a, '%');
    case 0x18: return v(0.001 * a * b, 'A');
    case 0x19: return v(b * 1.421 + a / 182, 'g/s');
    case 0x1A: return v((b - a).toDouble(), '°C');
    case 0x1B: return v((b - 128).abs() * 0.01 * a, '°');
    case 0x1C: return v((b - a).toDouble(), '');
    case 0x21: return v(a == 0 ? 100.0 * b : 100.0 * b / a, '%');
    case 0x22: return v((b - 128) * 0.01 * a, 'kW');
    case 0x23: return v(0.01 * a * b, 'L/h');
    case 0x24: return v(a * 2560.0 + b * 10, 'km');
    case 0x25: return VagValue(f, a, b, null, '', 'Pression huile ${b == 0 ? "OK" : "?"}');
    case 0x27: return v(b / 256 * a, 'mg/c');
    case 0x31: return v((b / 4) * a * 0.1, 'mg/h');
    case 0x33: return v(((b - 128) / 255) * a, 'mg/h');
    case 0x35: return v((b - 128) * 1.4222 + 0.006 * a, 'g/s');
    case 0x36: return v(a * 256.0 + b, '');
    case 0x37: return v(a * b / 200, 's');
    case 0x40: return v((a + b).toDouble(), 'Ω');
    case 0x41: return v(0.01 * a * (b - 127), 'mm');
    case 0xF4:
      return VagValue(f, a, b, b.toDouble(), '', 'b$a=$b (0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()})');
    default:
      return VagValue(f, a, b, null, '', 'f${f.toRadixString(16)} $a/$b');
  }
}

double clampD(double v, double lo, double hi) => math.max(lo, math.min(hi, v));
