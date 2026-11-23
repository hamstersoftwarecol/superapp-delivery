import 'package:equatable/equatable.dart';

/// One page of a list that the server hands out in chunks.
///
/// Pass [nextCursor] back to ask for the following page; `null` means this
/// was the last one.
class CursorPage<T> extends Equatable {
  const CursorPage({required this.items, this.nextCursor});

  /// Reads the API's cursor pagination envelope (`data` and `meta.next_cursor`).
  factory CursorPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) => CursorPage(
    items: [
      for (final item in json['data'] as List)
        fromJson(item as Map<String, dynamic>),
    ],
    nextCursor:
        (json['meta'] as Map<String, dynamic>?)?['next_cursor'] as String?,
  );

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [items, nextCursor];
}
