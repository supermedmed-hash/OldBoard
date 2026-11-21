import 'package:flutter/material.dart';

import '../models/vehicle_profile.dart';
import '../services/settings.dart';
import 'theme.dart';

/// Écran de sélection de profil véhicule (affiché au 1er lancement et accessible depuis Réglages).
class ProfilePickerScreen extends StatefulWidget {
  const ProfilePickerScreen({
    super.key,
    required this.settings,
    required this.onSelected,
    this.isFirstLaunch = false,
  });

  final AppSettings settings;
  final void Function(VehicleProfile profile) onSelected;
  final bool isFirstLaunch;

  @override
  State<ProfilePickerScreen> createState() => _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends State<ProfilePickerScreen> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.settings.profileId;
  }

  @override
  Widget build(BuildContext context) {
    final active = VehicleProfile.byId(_selectedId);

    return Scaffold(
      backgroundColor: Retro.bg,
      appBar: widget.isFirstLaunch
          ? null
          : AppBar(
              title: Text('Profil véhicule & Thème', style: Retro.title(16)),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isFirstLaunch) ...[
                Row(
                  children: [
                    Container(width: 4, height: 24, color: active.accent),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BIENVENUE SUR OLDBOARD', style: Retro.title(17, c: Retro.white)),
                        const SizedBox(height: 2),
                        const Text(
                          'Choisissez votre modèle VAG (1995–2004) pour adapter le thème et les calculs',
                          style: TextStyle(color: Retro.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth > 680 ? 2 : 1;
                    if (cols == 1) {
                      return ListView.separated(
                        itemCount: VehicleProfile.all.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _profileCard(VehicleProfile.all[i]),
                      );
                    }
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 3.1,
                      ),
                      itemCount: VehicleProfile.all.length,
                      itemBuilder: (_, i) => _profileCard(VehicleProfile.all[i]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: active.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => widget.onSelected(active),
                  child: Text(
                    widget.isFirstLaunch
                        ? 'DÉMARRER AVEC ${active.headerShort}'
                        : 'APPLIQUER LE PROFIL ${active.headerShort}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard(VehicleProfile p) {
    final selected = p.id == _selectedId;
    return InkWell(
      onTap: () => setState(() => _selectedId = p.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? p.accent.withValues(alpha: 0.12) : Retro.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? p.accent : Retro.border,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            BrandEmblem(brand: p.brand, accent: p.accent, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Retro.title(13.5, c: Retro.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Retro.silver, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? p.accent : Colors.transparent,
                border: Border.all(color: selected ? p.accent : Retro.muted, width: 2),
              ),
              child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Emblème vectoriel minimaliste pour chaque marque VAG (4 anneaux Audi, VW, SEAT, Škoda).
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
        child: CustomPaint(painter: _AudiRingsBrandPainter(color: Retro.white)),
      );
    }
    final label = switch (brand) {
      VehicleBrand.vw => 'VW',
      VehicleBrand.seat => 'S',
      VehicleBrand.skoda => 'ŠK',
      VehicleBrand.audi => 'AUDI',
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: brand == VehicleBrand.vw ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: brand == VehicleBrand.vw ? null : BorderRadius.circular(size * 0.22),
        color: accent.withValues(alpha: 0.16),
        border: Border.all(color: accent, width: 1.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Retro.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
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
