import 'package:flutter/material.dart';
import '../models/kisi_modeli.dart';
import '../services/person_editor_repository.dart';

class PersonEditorController extends ChangeNotifier {
  PersonEditorController({this.original, PersonEditorRepository? repository})
    : repository = repository ?? PersonEditorRepository() {
    ad.text = original?.ad ?? '';
    soyad.text = original?.soyad ?? '';
    email.text = original?.eposta ?? '';
    phone.text = original?.telefon ?? '';
    address.text = original?.adres ?? '';
    photo = original?.profilFotografi;
    for (final field in fields) {
      field.addListener(_changed);
    }
  }
  final KisiModeli? original;
  final PersonEditorRepository repository;
  final ad = TextEditingController(),
      soyad = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  List<TextEditingController> get fields => [ad, soyad, email, phone, address];
  String? photo, newPhoto, error;
  bool busy = false, dirty = false, _disposed = false;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    dirty = true;
    _emit();
  }

  void setPhoto(String? path) {
    if (busy) return;
    photo = path;
    newPhoto = path;
    _changed();
  }

  static String? validateName(String? value) =>
      (value?.trim().length ?? 0) < 2 ? 'En az 2 karakter girin.' : null;
  static String? validateEmail(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : 'Geçerli bir e-posta adresi girin.';
  }

  Future<bool> save() async {
    if (busy) return false;
    if (validateName(ad.text) != null ||
        validateName(soyad.text) != null ||
        validateEmail(email.text) != null)
      return false;
    busy = true;
    error = null;
    _emit();
    try {
      final now = DateTime.now();
      final person = KisiModeli(
        id: original?.id,
        ad: ad.text.trim(),
        soyad: soyad.text.trim(),
        eposta: email.text.trim(),
        telefon: phone.text.trim(),
        adres: address.text.trim(),
        profilFotografi: photo,
        olusturmaTarihi: original?.olusturmaTarihi ?? now,
        guncellemeTarihi: now,
      );
      await repository.save(person, original: original, newPhoto: newPhoto);
      dirty = false;
      return true;
    } catch (e) {
      error = 'Kişi kaydedilemedi. Bilgileriniz korunuyor. $e';
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }
}
