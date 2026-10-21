import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/auth_servisi.dart';
import '../services/arsiv_hesap_servisi.dart';

Future<bool> hesapEslesmesiniOnayla(BuildContext context, String qr) async {
  final data = jsonDecode(qr) as Map;
  if (data['account_version'] != 1)
    throw HesapHatasi('Iki cihazda da guncel hesap eslestirme surumu gerekli.');
  final account = Map<String, dynamic>.from(data['account'] as Map);
  ArsivHesapServisi.tanitimDogrula(account);
  return yoneticiDogrulamaDialog(
    context,
    hedef:
        '${account['ad']} ${account['soyad']}\nKullanıcı: ${account['kullanici_adi']}',
  );
}

Future<bool> yoneticiDogrulamaDialog(
  BuildContext context, {
  String? hedef,
  Future<AuthResult> Function(String)? dogrula,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _Dogrulama(
            hedef: hedef,
            dogrula: dogrula ?? AuthServisi.instance.yoneticiDogrula,
          ),
    ) ??
    false;

class _Dogrulama extends StatefulWidget {
  final String? hedef;
  final Future<AuthResult> Function(String) dogrula;
  const _Dogrulama({this.hedef, required this.dogrula});
  @override
  State<_Dogrulama> createState() => _DogrulamaState();
}

class _DogrulamaState extends State<_Dogrulama> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.dogrula(_password.text);
      if (!mounted) return;
      if (result.success) {
        Navigator.pop(context, true);
        return;
      }
      setState(() => _error = result.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Doğrulama tamamlanamadı. Yeniden deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Yönetici doğrulaması'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.hedef == null
                    ? 'Bu arşive cihaz bağlamak için bu cihazdaki yönetici şifrenizi girin.'
                    : '${widget.hedef}\n\nBu hesapla bağlanmayı onaylamak için bu cihazdaki yönetici şifrenizi girin. Mevcut kişiler ve belgeler korunur.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Bu cihazın yönetici şifresi',
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Doğrulanıyor...' : 'Doğrula ve onayla'),
        ),
      ],
    ),
  );
}
