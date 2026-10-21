import 'dart:io';
import 'package:flutter/material.dart';
import '../../providers/person_editor_controller.dart';
import '../common/form_section.dart';
import '../document_editor/editor_section.dart';

class PersonForm extends StatelessWidget {
  const PersonForm({
    super.key,
    required this.controller,
    required this.onPhoto,
  });
  final PersonEditorController controller;
  final VoidCallback onPhoto;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSection(
          number: 1,
          title: 'Temel Bilgiler',
          subtitle: 'Kişinin temel bilgilerini girin.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EditorColumns(
                children: [
                  LabeledFormField(
                    label: 'Ad',
                    hint: 'Ad girin…',
                    icon: Icons.person_outline,
                    controller: c.ad,
                    requiredField: true,
                    validator: PersonEditorController.validateName,
                    autofillHints: const [AutofillHints.givenName],
                  ),
                  LabeledFormField(
                    label: 'Soyad',
                    hint: 'Soyad girin…',
                    icon: Icons.person_outline,
                    controller: c.soyad,
                    requiredField: true,
                    validator: PersonEditorController.validateName,
                    autofillHints: const [AutofillHints.familyName],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onPhoto,
                  icon:
                      c.photo == null
                          ? const Icon(Icons.add_a_photo_outlined, size: 20)
                          : ClipOval(
                            child: Image.file(
                              File(c.photo!),
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              cacheWidth: 100,
                              errorBuilder:
                                  (_, _, _) => const Icon(Icons.person_outline),
                            ),
                          ),
                  label: Text(
                    c.photo == null
                        ? 'Profil fotoğrafı ekle (isteğe bağlı)'
                        : 'Profil fotoğrafını değiştir',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FormSection(
          number: 2,
          title: 'İletişim Bilgileri',
          subtitle:
              'Kişinin iletişim bilgilerini girin. Bu alanlar isteğe bağlıdır.',
          child: Column(
            children: [
              EditorColumns(
                children: [
                  LabeledFormField(
                    label: 'E-posta',
                    hint: 'ornek@eposta.com',
                    icon: Icons.mail_outline,
                    controller: c.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: PersonEditorController.validateEmail,
                    autofillHints: const [AutofillHints.email],
                  ),
                  LabeledFormField(
                    label: 'Telefon',
                    hint: 'Telefon numarası girin…',
                    icon: Icons.phone_android,
                    controller: c.phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LabeledFormField(
                label: 'Adres',
                hint: 'Adres girin…',
                icon: Icons.location_on_outlined,
                controller: c.address,
                keyboardType: TextInputType.multiline,
                lines: 2,
                autofillHints: const [AutofillHints.fullStreetAddress],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
