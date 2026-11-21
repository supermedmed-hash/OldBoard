import 'package:flutter/material.dart';

import '../models/dashboard_layout.dart';
import '../services/settings.dart';
import 'theme.dart';

/// Sélecteur rapide en feuille modale (utilisé aussi sur appui long directement depuis le tableau de bord).
Future<void> showHeroSlotPicker(
  BuildContext context, {
  required AppSettings settings,
  required int slotIndex,
}) async {
  final current = settings.heroSlots[slotIndex];
  final accent = settings.profile.accent;
  final picked = await showModalBottomSheet<HeroSlotType>(
    context: context,
    backgroundColor: Retro.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text(
              'GRANDE CARTE ${slotIndex + 1} — CHOISIR LA DONNÉE',
              style: Retro.title(12.5, c: Retro.titleWhite),
            ),
          ),
          for (final t in HeroSlotType.values)
            ListTile(
              title: Text(t.label, style: Retro.title(13.5, c: Retro.white)),
              subtitle: Text(t.subtitle, style: const TextStyle(color: Retro.grey, fontSize: 12)),
              trailing: t == current ? Icon(Icons.check_circle_rounded, color: accent) : null,
              onTap: () => Navigator.pop(ctx, t),
            ),
        ],
      ),
    ),
  );
  if (picked != null) {
    settings.setHeroSlot(slotIndex, picked);
  }
}

Future<void> showTileSlotPicker(
  BuildContext context, {
  required AppSettings settings,
  required int slotIndex,
}) async {
  final current = settings.tileSlots[slotIndex];
  final accent = settings.profile.accent;
  final picked = await showModalBottomSheet<TileSlotType>(
    context: context,
    backgroundColor: Retro.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scroll) => SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'CASE ${slotIndex + 1} — CHOISIR LE CAPTEUR OBD',
                style: Retro.title(12.5, c: Retro.titleWhite),
              ),
            ),
            const Divider(color: Retro.borderSubtle, height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  for (final t in TileSlotType.values)
                    ListTile(
                      dense: true,
                      title: Text(t.label, style: const TextStyle(color: Retro.white, fontWeight: FontWeight.w700)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.unitHint, style: const TextStyle(color: Retro.grey, fontSize: 11.5)),
                          if (t == current) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle_rounded, color: accent, size: 20),
                          ],
                        ],
                      ),
                      onTap: () => Navigator.pop(ctx, t),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked != null) {
    settings.setTileSlot(slotIndex, picked);
  }
}

/// Écran complet de personnalisation du tableau de bord (préréglages + 2 grandes cartes + 6 cases).
class DashboardEditorScreen extends StatelessWidget {
  const DashboardEditorScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final accent = settings.profile.accent;
        return Scaffold(
          backgroundColor: Retro.bg,
          appBar: AppBar(
            title: const Text(
              'Personnaliser le tableau de bord',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              TextButton(
                onPressed: () => settings.applyDashboardPreset(DashboardPreset.all.first),
                child: Text('Défaut', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Retro.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Retro.borderSubtle),
                  ),
                  child: const Text(
                    'Astuce : tu peux aussi faire un appui long directement sur n\'importe quelle carte '
                    'ou case du tableau de bord pour changer sa donnée en 1 seconde.',
                    style: TextStyle(color: Retro.silver, fontSize: 12, height: 1.35),
                  ),
                ),
                const SizedBox(height: 16),
                Text('PRÉRÉGLAGES RAPIDES', style: Retro.title(12, c: accent)),
                const SizedBox(height: 8),
                for (final preset in DashboardPreset.all) ...[
                  _presetCard(context, preset, accent),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                Text('GRANDES CARTES DU HAUT (2)', style: Retro.title(12, c: accent)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _heroSlotButton(context, 0, accent)),
                    const SizedBox(width: 8),
                    Expanded(child: _heroSlotButton(context, 1, accent)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('CASES CAPTEURS (6)', style: Retro.title(12, c: accent)),
                const SizedBox(height: 8),
                for (var row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var col = 0; col < 3; col++) ...[
                        if (col > 0) const SizedBox(width: 8),
                        Expanded(child: _tileSlotButton(context, row * 3 + col, accent)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _presetCard(BuildContext context, DashboardPreset preset, Color accent) {
    final active = _listEq(settings.heroSlots, preset.heroes) && _listEq(settings.tileSlots, preset.tiles);
    return InkWell(
      onTap: () => settings.applyDashboardPreset(preset),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Retro.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? accent : Retro.border, width: active ? 1.8 : 1.0),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.name, style: Retro.title(13, c: Retro.white)),
                  const SizedBox(height: 3),
                  Text(preset.description, style: const TextStyle(color: Retro.grey, fontSize: 11.5, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              active ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: active ? accent : Retro.silver,
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroSlotButton(BuildContext context, int index, Color accent) {
    final t = settings.heroSlots[index];
    return InkWell(
      onTap: () => showHeroSlotPicker(context, settings: settings, slotIndex: index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Retro.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CARTE ${index + 1}', style: const TextStyle(color: Retro.grey, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Retro.title(13, c: Retro.white)),
            const SizedBox(height: 2),
            const Text('Toucher pour changer', style: TextStyle(color: Retro.silver, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _tileSlotButton(BuildContext context, int index, Color accent) {
    final t = settings.tileSlots[index];
    return InkWell(
      onTap: () => showTileSlotPicker(context, settings: settings, slotIndex: index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: Retro.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Retro.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CASE ${index + 1}', style: const TextStyle(color: Retro.grey, fontSize: 9.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              t.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Retro.white, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2),
            ),
            const SizedBox(height: 4),
            Text(t.unitHint, style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
