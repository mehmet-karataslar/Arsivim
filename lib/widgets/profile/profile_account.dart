import 'package:flutter/material.dart';
import '../../models/kisi_modeli.dart';
import '../../services/auth_servisi.dart';
import 'profile_section.dart';

class ProfileAccount extends StatefulWidget {
  const ProfileAccount({super.key, this.kullanici, this.loadAccount});
  final KisiModeli? kullanici;
  final Future<Map<String, dynamic>> Function()? loadAccount;

  @override
  State<ProfileAccount> createState() => _ProfileAccountState();
}

class _ProfileAccountState extends State<ProfileAccount> {
  Future<Map<String, dynamic>>? _account;

  void _readAccount() {
    final loader = widget.loadAccount;
    _account =
        loader != null
            ? Future.sync(loader)
            : AuthServisi.instance.isLoggedIn
            ? AuthServisi.instance.hesapTanitim()
            : null;
  }

  @override
  void initState() {
    super.initState();
    _readAccount();
  }

  @override
  void didUpdateWidget(covariant ProfileAccount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kullanici?.id != widget.kullanici?.id ||
        oldWidget.loadAccount != widget.loadAccount) {
      _readAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ProfileSection(
      title: 'Hesap bilgileri',
      icon: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: const Icon(Icons.person_outline_rounded, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            widget.kullanici?.tamAd ?? 'Kullanıcı',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Text(
            'Kullanıcı adı',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SelectableText(widget.kullanici?.kullaniciAdi ?? '—'),
          if (_account != null) ...[
            const SizedBox(height: 16),
            const Text('Arşiv yöneticisi'),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>>(
              future: _account,
              builder: (context, snapshot) {
                final account = snapshot.data;
                if (snapshot.hasError) {
                  return const Text(
                    'Hesap doğrulanamadı. Yeniden giriş yapın.',
                  );
                }
                if (account == null) return const LinearProgressIndicator();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account['bagli'] == 1
                          ? 'Ortak arşive bağlı'
                          : 'Henüz başka cihaz bağlanmadı',
                    ),
                    const SizedBox(height: 8),
                    SelectableText('Arşiv: ${account['arsiv_id']}'),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
