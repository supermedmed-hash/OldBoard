import 'package:flutter/material.dart';

import '../models/vehicle_profile.dart';
import '../services/settings.dart';
import 'brand_emblems.dart';
import 'theme.dart';

export 'brand_emblems.dart' show BrandEmblem;

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
    final compactH = MediaQuery.sizeOf(context).height < 430;

    return Scaffold(
      backgroundColor: Retro.bg,
      appBar: widget.isFirstLaunch
          ? null
          : AppBar(
              title: Text(
                'Profil véhicule & Thème',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Retro.title(16),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, compactH ? 8 : 14, 14, compactH ? 8 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isFirstLaunch) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(width: 4, height: compactH ? 24 : 32, color: active.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'BIENVENUE SUR OLDBOARD',
                              maxLines: 1,
                              style: Retro.title(17, c: Retro.white),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Choisissez votre modèle VAG (1995–2004) pour adapter le thème et les calculs',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Retro.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compactH ? 8 : 14),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth > 620 ? 2 : 1;
                    if (cols == 1) {
                      return ListView.separated(
                        itemCount: VehicleProfile.all.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _profileCard(VehicleProfile.all[i], gridMode: false),
                      );
                    }
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 92,
                      ),
                      itemCount: VehicleProfile.all.length,
                      itemBuilder: (_, i) => _profileCard(VehicleProfile.all[i], gridMode: true),
                    );
                  },
                ),
              ),
              SizedBox(height: compactH ? 8 : 12),
              SizedBox(
                height: compactH ? 42 : 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: active.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => widget.onSelected(active),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.isFirstLaunch
                          ? 'DÉMARRER AVEC ${active.headerShort}'
                          : 'APPLIQUER LE PROFIL ${active.headerShort}',
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard(VehicleProfile p, {required bool gridMode}) {
    final selected = p.id == _selectedId;
    return InkWell(
      onTap: () => setState(() => _selectedId = p.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: gridMode ? 8 : 12),
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
            SizedBox(
              width: 48,
              child: Center(
                child: BrandEmblem(brand: p.brand, accent: p.accent, size: 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Retro.title(13.5, c: Retro.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Retro.silver, fontSize: 11.5, height: 1.2),
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
