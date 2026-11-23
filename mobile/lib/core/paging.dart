/// Adds [more] to [current], skipping anything already there (a new item can
/// slip between pages while the list is being read).
List<T> appendUnique<T>(
  List<T> current,
  List<T> more,
  Object Function(T item) idOf,
) {
  final seen = {for (final item in current) idOf(item)};

  return [
    ...current,
    for (final item in more)
      if (seen.add(idOf(item))) item,
  ];
}

/// Puts a freshly fetched first page over a list that may already hold more
/// pages: items in [firstPage] win and lead, the rest keep their place.
List<T> refreshFirstPage<T>(
  List<T> current,
  List<T> firstPage,
  Object Function(T item) idOf,
) {
  final fresh = {for (final item in firstPage) idOf(item)};

  return [
    ...firstPage,
    for (final item in current)
      if (!fresh.contains(idOf(item))) item,
  ];
}
