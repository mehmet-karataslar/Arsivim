enum DocumentSort { newest, oldest, name, largest }

class DocumentFilters {
  const DocumentFilters({
    this.query = '',
    this.extension,
    this.categoryId,
    this.personId,
    this.from,
    this.until,
    this.large = false,
    this.shared = false,
    this.sort = DocumentSort.newest,
  });
  final String query;
  final String? extension;
  final int? categoryId, personId;
  final DateTime? from, until;
  final bool large, shared;
  final DocumentSort sort;
  bool get hasFilters =>
      extension != null ||
      categoryId != null ||
      personId != null ||
      from != null ||
      until != null ||
      large ||
      shared;
  DocumentFilters copyWith({
    String? query,
    String? extension,
    int? categoryId,
    int? personId,
    DateTime? from,
    DateTime? until,
    bool? large,
    bool? shared,
    DocumentSort? sort,
    bool clearExtension = false,
    bool clearCategory = false,
    bool clearPerson = false,
    bool clearDates = false,
  }) => DocumentFilters(
    query: query ?? this.query,
    extension: clearExtension ? null : extension ?? this.extension,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    personId: clearPerson ? null : personId ?? this.personId,
    from: clearDates ? null : from ?? this.from,
    until: clearDates ? null : until ?? this.until,
    large: large ?? this.large,
    shared: shared ?? this.shared,
    sort: sort ?? this.sort,
  );
}
