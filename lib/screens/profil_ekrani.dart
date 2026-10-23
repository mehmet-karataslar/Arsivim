import '../widgets/common/workspace_layout.dart';
import 'package:flutter/material.dart';
import '../models/kisi_modeli.dart';
import '../widgets/profile/profile_account.dart';
import '../widgets/profile/profile_appearance.dart';
import '../widgets/profile/profile_update.dart';

/// Hesap ve görünüm, tek Profil sekmesinde bağımsız bölümler olarak tutulur.
class ProfilEkrani extends StatelessWidget {
  const ProfilEkrani({super.key, this.kullanici, this.showHeading = true});
  final KisiModeli? kullanici;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        return ListView(
          padding:
              WorkspaceLayout.compact(context)
                  ? const EdgeInsets.symmetric(vertical: 12)
                  : const EdgeInsets.all(32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeading) ...[
                      Text(
                        'Profil',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hesap bilgilerinizi, görünümü ve güncellemeleri buradan yönetin.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 300,
                            child: ProfileAccount(kullanici: kullanici),
                          ),
                          const SizedBox(width: 24),
                          const Expanded(child: ProfileAppearance()),
                        ],
                      )
                    else ...[
                      ProfileAccount(kullanici: kullanici),
                      const SizedBox(height: 20),
                      const ProfileAppearance(),
                    ],
                    const SizedBox(height: 20),
                    const ProfileUpdate(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
