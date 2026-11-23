import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_delivery/core/paging.dart';

void main() {
  int idOf(int item) => item;

  group('appendUnique', () {
    test('adds only what is new, keeping the order', () {
      expect(appendUnique([1, 2, 3], [3, 4, 2, 5], idOf), [1, 2, 3, 4, 5]);
    });

    test('also removes repeats inside the new page', () {
      expect(appendUnique([1], [2, 2, 3], idOf), [1, 2, 3]);
    });
  });

  group('refreshFirstPage', () {
    test('puts the fresh page first and keeps the older pages after it', () {
      expect(refreshFirstPage([3, 2, 1, 0], [4, 3, 2], idOf), [4, 3, 2, 1, 0]);
    });

    test('drops stale copies of items that are in the fresh page', () {
      expect(refreshFirstPage([9, 5], [5, 9], idOf), [5, 9]);
    });
  });
}
