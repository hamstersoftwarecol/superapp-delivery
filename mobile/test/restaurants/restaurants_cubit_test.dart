import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/restaurants/restaurants.dart';

class _MockRestaurantRepository extends Mock implements RestaurantRepository {}

Restaurant _restaurant(int id) => Restaurant(
  id: id,
  name: 'Restaurante $id',
  address: 'Calle $id',
  deliveryFeeCents: 0,
  isOpen: true,
);

void main() {
  late _MockRestaurantRepository repository;

  setUp(() => repository = _MockRestaurantRepository());

  RestaurantsCubit build() =>
      RestaurantsCubit(restaurantRepository: repository);

  group('RestaurantsCubit', () {
    blocTest<RestaurantsCubit, RestaurantsState>(
      'load shows the first page and remembers where the next one starts',
      setUp: () => when(() => repository.getRestaurants()).thenAnswer(
        (_) async => CursorPage(
          items: [_restaurant(1), _restaurant(2)],
          nextCursor: 'c1',
        ),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const RestaurantsState(status: LoadStatus.loading),
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: [_restaurant(1), _restaurant(2)],
          nextCursor: 'c1',
        ),
      ],
    );

    blocTest<RestaurantsCubit, RestaurantsState>(
      'loadMore appends the next page and stops at the last one',
      setUp: () =>
          when(() => repository.getRestaurants(cursor: 'c1'))
              .thenAnswer((_) async => CursorPage(items: [_restaurant(3)])),
      build: build,
      seed: () => RestaurantsState(
        status: LoadStatus.success,
        restaurants: [_restaurant(1), _restaurant(2)],
        nextCursor: 'c1',
      ),
      act: (cubit) => cubit.loadMore(),
      expect: () => [
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: [_restaurant(1), _restaurant(2)],
          nextCursor: 'c1',
          isLoadingMore: true,
        ),
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: [_restaurant(1), _restaurant(2), _restaurant(3)],
        ),
      ],
    );

    blocTest<RestaurantsCubit, RestaurantsState>(
      'loadMore skips restaurants it already has',
      setUp: () => when(() => repository.getRestaurants(cursor: 'c1'))
          .thenAnswer(
            (_) async => CursorPage(items: [_restaurant(2), _restaurant(3)]),
          ),
      build: build,
      seed: () => RestaurantsState(
        status: LoadStatus.success,
        restaurants: [_restaurant(1), _restaurant(2)],
        nextCursor: 'c1',
      ),
      act: (cubit) => cubit.loadMore(),
      verify: (cubit) =>
          expect(cubit.state.restaurants.map((r) => r.id), [1, 2, 3]),
    );

    blocTest<RestaurantsCubit, RestaurantsState>(
      'loadMore does nothing when there is no next page',
      build: build,
      seed: () => RestaurantsState(
        status: LoadStatus.success,
        restaurants: [_restaurant(1)],
      ),
      act: (cubit) => cubit.loadMore(),
      expect: () => <RestaurantsState>[],
      verify: (_) => verifyNever(
        () => repository.getRestaurants(cursor: any(named: 'cursor')),
      ),
    );

    blocTest<RestaurantsCubit, RestaurantsState>(
      'a second scroll event while a page is loading does not ask twice',
      setUp: () =>
          when(() => repository.getRestaurants(cursor: 'c1'))
              .thenAnswer((_) async => CursorPage(items: [_restaurant(3)])),
      build: build,
      seed: () => RestaurantsState(
        status: LoadStatus.success,
        restaurants: [_restaurant(1)],
        nextCursor: 'c1',
      ),
      act: (cubit) {
        cubit
          ..loadMore()
          ..loadMore();
      },
      verify: (_) =>
          verify(() => repository.getRestaurants(cursor: 'c1')).called(1),
    );

    blocTest<RestaurantsCubit, RestaurantsState>(
      'a failed loadMore keeps the list and lets the user retry',
      setUp: () =>
          when(() => repository.getRestaurants(cursor: 'c1'))
              .thenThrow(const ApiException(0, 'Sin conexión')),
      build: build,
      seed: () => RestaurantsState(
        status: LoadStatus.success,
        restaurants: [_restaurant(1)],
        nextCursor: 'c1',
      ),
      act: (cubit) => cubit.loadMore(),
      expect: () => [
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: [_restaurant(1)],
          nextCursor: 'c1',
          isLoadingMore: true,
        ),
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: [_restaurant(1)],
          nextCursor: 'c1',
          loadMoreFailed: true,
        ),
      ],
    );

    blocTest<RestaurantsCubit, RestaurantsState>(
      'load starts over from the first page',
      setUp: () =>
          when(() => repository.getRestaurants())
              .thenAnswer((_) async => CursorPage(items: [_restaurant(9)])),
      build: build,
      seed: () => RestaurantsState(
        status: LoadStatus.success,
        restaurants: [_restaurant(1), _restaurant(2)],
        nextCursor: 'c1',
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.restaurants.map((r) => r.id), [9]);
        expect(cubit.state.nextCursor, isNull);
      },
    );
  });
}
