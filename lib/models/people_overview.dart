import 'kisi_modeli.dart';
import 'belge_modeli.dart';
import 'kategori_modeli.dart';

enum PeopleSort { name, updated, documents, newest }

enum PeopleDocumentFilter { all, withDocuments, withoutDocuments }

class PersonSummary {
  const PersonSummary({
    required this.person,
    required this.documentCount,
    required this.categories,
    required this.updated,
  });
  final KisiModeli person;
  final int documentCount;
  final List<KategoriModeli> categories;
  final DateTime updated;
}

class PeopleOverview {
  const PeopleOverview(this.people, {this.uniqueDocuments});
  final int? uniqueDocuments;
  final List<PersonSummary> people;
  int get documentCount =>
      uniqueDocuments ??
      people.fold(0, (sum, item) => sum + item.documentCount);
  List<KategoriModeli> get categories =>
      {
        for (final person in people)
          for (final category in person.categories) category.id: category,
      }.values.toList();
  double get average =>
      people.isEmpty
          ? 0
          : people.fold(0, (sum, item) => sum + item.documentCount) /
              people.length;
}

class PersonFolder {
  const PersonFolder(this.path, this.name, this.count);
  final String path, name;
  final int count;
}

class PersonDetails {
  const PersonDetails({
    required this.personId,
    required this.documents,
    required this.folders,
    required this.notes,
  });
  final int personId;
  final List<BelgeModeli> documents, notes;
  final List<PersonFolder> folders;
}
