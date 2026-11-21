import 'package:flutter/material.dart';

import '../models/vehicle_profile.dart';
import 'theme.dart';

/// Emblèmes vectoriels OEM officiels (monochrome haute lisibilité) pour chaque marque VAG :
/// - Audi : 4 anneaux entrelacés
/// - Volkswagen : cercle VW officiel
/// - SEAT : "S" géométrique officiel
/// - Škoda : flèche ailée officielle dans son cercle
class BrandEmblem extends StatelessWidget {
  const BrandEmblem({
    super.key,
    required this.brand,
    required this.accent,
    this.size = 24,
  });

  final VehicleBrand brand;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (brand == VehicleBrand.audi) {
      return SizedBox(
        width: size * 1.45,
        height: size * 0.55,
        child: const CustomPaint(painter: _AudiRingsBrandPainter(color: Retro.white)),
      );
    }
    final path = switch (brand) {
      VehicleBrand.vw => _vwPath,
      VehicleBrand.seat => _seatPath,
      VehicleBrand.skoda => _skodaPath,
      VehicleBrand.audi => _vwPath,
    };
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SvgPathBrandPainter(path: path, color: Retro.white),
      ),
    );
  }
}

class _AudiRingsBrandPainter extends CustomPainter {
  const _AudiRingsBrandPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height * 0.43;
    final cy = size.height / 2;
    final step = r * 1.42;
    final totalW = step * 3 + r * 2;
    final startX = (size.width - totalW) / 2 + r;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.13
      ..color = color;
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(startX + i * step, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudiRingsBrandPainter old) => old.color != color;
}

class _SvgPathBrandPainter extends CustomPainter {
  const _SvgPathBrandPainter({required this.path, required this.color});
  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SvgPathBrandPainter old) => old.path != path || old.color != color;
}

// Chemins vectoriels 24x24 (source : Simple Icons, compilés une seule fois en mémoire).
final Path _vwPath = _parseSvgPath(
  'M12 0C5.36 0 0 5.36 0 12S5.36 24 12 24 24 18.64 24 12 18.64 0 12 0'
  'M12 1.41C13.2 1.41 14.36 1.63 15.43 2L12.13 9.13C12.09 9.17 12.09 9.26 12 9.26S11.91 9.17 11.87 9.13L8.57 2C9.64 1.63 10.8 1.42 12 1.42'
  'M6.9 2.74L10.72 10.97C10.8 11.14 10.89 11.19 11 11.19H13C13.12 11.19 13.2 11.14 13.29 10.97L17.06 2.74C18.64 3.64 20 4.93 20.96 6.47L15.6 16.84C15.56 16.93 15.5 16.97 15.47 16.97C15.39 16.97 15.39 16.89 15.34 16.84L13.29 12.3C13.2 12.13 13.12 12.09 13 12.09H11C10.89 12.09 10.8 12.13 10.71 12.3L8.66 16.84C8.61 16.89 8.62 16.97 8.53 16.97C8.44 16.97 8.44 16.89 8.4 16.84L3 6.47C3.94 4.93 5.32 3.64 6.9 2.74'
  'M2.06 8.53L8.23 20.53C8.31 20.7 8.4 20.83 8.62 20.83C8.83 20.83 8.91 20.7 9 20.53L11.87 14.14C11.91 14.06 11.96 14 12 14C12.09 14 12.09 14.1 12.13 14.14L15.04 20.53C15.13 20.7 15.21 20.83 15.43 20.83C15.64 20.83 15.73 20.7 15.81 20.53L22 8.53C22.37 9.6 22.59 10.76 22.59 12C22.54 17.79 17.79 22.59 12 22.59C6.21 22.59 1.46 17.79 1.46 12C1.46 10.8 1.67 9.65 2.06 8.53Z',
  fillType: PathFillType.evenOdd,
);

final Path _seatPath = _parseSvgPath(
  'M0 10.325l23.98 4.46c-.021.657-.062 2.712-.103 3.903-.041 1.418-.35 2.281-.925 2.815-.801.72-1.747.884-4.007 1.007-5.219.288-10.54.247-17.219-.226-.699-.04-.966-.185-1.089-.267-.288-.205-.329-.431-.411-1.603-.062-.801-.164-3.123-.205-3.904 3.102.206 7.849.37 11.712.37.966 0 3.493.02 4.171.02.534 0 1.233-.143 1.582-.698L0 13.222z'
  'm.02-1.253c.021-.76.062-2.65.103-3.76.041-1.418.35-2.281.925-2.815.801-.72 1.747-.884 4.007-1.007 5.219-.288 10.54-.247 17.219.226.699.04.966.185 1.089.267.288.205.329.431.411 1.603.041.678.144 2.486.185 3.472-2.301-.123-6.206-.308-9.596-.35-3.39-.04-6.452.021-6.822.063-.74.102-1.089.452-1.192.595L24 10.634v2.568Z',
);

final Path _skodaPath = _parseSvgPath(
  'M12 0C5.3726 0 0 5.3726 0 12s5.3726 12 12 12 12-5.3726 12-12S18.6274 0 12 0Z'
  'm0 22.9636C5.945 22.9636 1.0364 18.055 1.0364 12 1.0364 5.945 5.945 1.0364 12 1.0364S22.9636 5.945 22.9636 12 18.055 22.9636 12 22.9636Z'
  'm5.189-7.2325-.269.7263h-.984c.263-.7089 3.5783-8.6177-2.9362-13.9819a9.5254 9.5254 0 0 0-4.0531.4483c.2172.175 2.474 2.0276 3.5373 4.315l-.312.084c-.5861-.6387-2.7156-2.9833-4.7448-3.7379a9.6184 9.6184 0 0 0-2.8448 2.3597c.953.4875 3.4432 1.9748 4.3896 3.1302-.0542.0244-.267.139-.267.139-1.736-1.3195-4.8199-2.0043-4.9775-2.0383a9.5126 9.5126 0 0 0-1.2267 3.6098c4.7759.9613 6.0618 3.1715 6.2818 5.6721H7.878l-1.5545-.6776a.8563.8563 0 0 0-.2524-.0531H3.1767a9.587 9.587 0 0 0 1.9267 2.9155h1.2334c.1063 0 .1993-.0133.2923-.0664l1.2489-.6378h9.042l.269.7264a4.8386 4.8386 0 0 0 2.9466-1.4667 4.839 4.839 0 0 0-2.9467-1.4666z'
  'm-4.14-.5786a1.1863 1.1863 0 0 1-.5038-1.2162 1.1862 1.1862 0 0 1 .931-.9309 1.1863 1.1863 0 0 1 1.2161.5038c.3098.4636.2563 1.0924-.1473 1.496-.4032.4032-1.0318.4574-1.496.1473z',
  fillType: PathFillType.evenOdd,
);

/// Parseur léger de chemin SVG (`M/m L/l H/h V/v C/c S/s A/a Z/z`) sans dépendance externe.
Path _parseSvgPath(String d, {PathFillType fillType = PathFillType.nonZero}) {
  final path = Path()..fillType = fillType;
  final len = d.length;
  var i = 0;

  void skipSep() {
    while (i < len) {
      final c = d.codeUnitAt(i);
      if (c == 32 || c == 9 || c == 10 || c == 13 || c == 44) {
        i++;
      } else {
        break;
      }
    }
  }

  bool isCmd(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);

  double readNum() {
    skipSep();
    final start = i;
    if (i < len && (d[i] == '+' || d[i] == '-')) i++;
    while (i < len && d.codeUnitAt(i) >= 48 && d.codeUnitAt(i) <= 57) {
      i++;
    }
    if (i < len && d[i] == '.') {
      i++;
      while (i < len && d.codeUnitAt(i) >= 48 && d.codeUnitAt(i) <= 57) {
        i++;
      }
    }
    if (i < len && (d[i] == 'e' || d[i] == 'E')) {
      i++;
      if (i < len && (d[i] == '+' || d[i] == '-')) i++;
      while (i < len && d.codeUnitAt(i) >= 48 && d.codeUnitAt(i) <= 57) {
        i++;
      }
    }
    return double.parse(d.substring(start, i));
  }

  int readFlag() {
    skipSep();
    final v = d.codeUnitAt(i) == 49 ? 1 : 0;
    i++;
    return v;
  }

  double cx = 0, cy = 0;
  double sx = 0, sy = 0;
  double lastCpX = 0, lastCpY = 0;
  String cmd = '';
  String prevCmd = '';

  while (true) {
    skipSep();
    if (i >= len) break;
    if (isCmd(d.codeUnitAt(i))) {
      cmd = d[i++];
    }

    switch (cmd) {
      case 'M':
      case 'm':
        final x = readNum();
        final y = readNum();
        if (cmd == 'm') {
          cx += x;
          cy += y;
        } else {
          cx = x;
          cy = y;
        }
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
        prevCmd = cmd;
        cmd = cmd == 'm' ? 'l' : 'L';
      case 'L':
      case 'l':
        final x = readNum();
        final y = readNum();
        cx = cmd == 'l' ? cx + x : x;
        cy = cmd == 'l' ? cy + y : y;
        path.lineTo(cx, cy);
        prevCmd = cmd;
      case 'H':
      case 'h':
        final x = readNum();
        cx = cmd == 'h' ? cx + x : x;
        path.lineTo(cx, cy);
        prevCmd = cmd;
      case 'V':
      case 'v':
        final y = readNum();
        cy = cmd == 'v' ? cy + y : y;
        path.lineTo(cx, cy);
        prevCmd = cmd;
      case 'C':
      case 'c':
        final x1 = readNum(), y1 = readNum();
        final x2 = readNum(), y2 = readNum();
        final x = readNum(), y = readNum();
        final ax1 = cmd == 'c' ? cx + x1 : x1;
        final ay1 = cmd == 'c' ? cy + y1 : y1;
        final ax2 = cmd == 'c' ? cx + x2 : x2;
        final ay2 = cmd == 'c' ? cy + y2 : y2;
        final ax = cmd == 'c' ? cx + x : x;
        final ay = cmd == 'c' ? cy + y : y;
        path.cubicTo(ax1, ay1, ax2, ay2, ax, ay);
        lastCpX = ax2;
        lastCpY = ay2;
        cx = ax;
        cy = ay;
        prevCmd = cmd;
      case 'S':
      case 's':
        final hasPrevCubic = prevCmd == 'C' || prevCmd == 'c' || prevCmd == 'S' || prevCmd == 's';
        final ax1 = hasPrevCubic ? 2 * cx - lastCpX : cx;
        final ay1 = hasPrevCubic ? 2 * cy - lastCpY : cy;
        final x2 = readNum(), y2 = readNum();
        final x = readNum(), y = readNum();
        final ax2 = cmd == 's' ? cx + x2 : x2;
        final ay2 = cmd == 's' ? cy + y2 : y2;
        final ax = cmd == 's' ? cx + x : x;
        final ay = cmd == 's' ? cy + y : y;
        path.cubicTo(ax1, ay1, ax2, ay2, ax, ay);
        lastCpX = ax2;
        lastCpY = ay2;
        cx = ax;
        cy = ay;
        prevCmd = cmd;
      case 'A':
      case 'a':
        final rx = readNum(), ry = readNum();
        final rot = readNum();
        final largeArc = readFlag();
        final sweep = readFlag();
        final x = readNum(), y = readNum();
        final ax = cmd == 'a' ? cx + x : x;
        final ay = cmd == 'a' ? cy + y : y;
        path.arcToPoint(
          Offset(ax, ay),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: largeArc != 0,
          clockwise: sweep != 0,
        );
        cx = ax;
        cy = ay;
        prevCmd = cmd;
      case 'Z':
      case 'z':
        path.close();
        cx = sx;
        cy = sy;
        prevCmd = cmd;
      default:
        break;
    }
  }
  return path;
}
