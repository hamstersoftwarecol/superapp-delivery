import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/core/widgets/network_photo.dart';
import 'package:superapp_delivery/restaurants/restaurants.dart';

class _MockRestaurantsCubit extends MockCubit<RestaurantsState>
    implements RestaurantsCubit {}

Restaurant _restaurant(int id) => Restaurant(
  id: id,
  name: 'Restaurante $id',
  address: 'Calle $id',
  deliveryFeeCents: 300000,
  isOpen: true,
);

void main() {
  late _MockRestaurantsCubit cubit;

  setUp(() {
    cubit = _MockRestaurantsCubit();
    when(() => cubit.loadMore()).thenAnswer((_) async {});
    when(() => cubit.load()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, RestaurantsState state) {
    when(() => cubit.state).thenReturn(state);

    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<RestaurantsCubit>.value(
            value: cubit,
            child: const RestaurantsView(),
          ),
        ),
      ),
    );
  }

  testWidgets('scrolling near the end asks for the next page', (tester) async {
    await pump(
      tester,
      RestaurantsState(
        status: LoadStatus.success,
        restaurants: [for (var i = 1; i <= 20; i++) _restaurant(i)],
        nextCursor: 'siguiente',
      ),
    );
    verifyNever(() => cubit.loadMore());

    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pump();

    verify(() => cubit.loadMore()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('shows a spinner at the bottom while the next page loads', (
    tester,
  ) async {
    await pump(
      tester,
      RestaurantsState(
        status: LoadStatus.success,
        restaurants: [_restaurant(1)],
        nextCursor: 'c',
        isLoadingMore: true,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('offers a retry when the next page failed', (tester) async {
    await pump(
      tester,
      RestaurantsState(
        status: LoadStatus.success,
        restaurants: [_restaurant(1)],
        nextCursor: 'c',
        loadMoreFailed: true,
      ),
    );

    await tester.tap(find.text('No se pudo cargar más. Reintentar'));

    verify(() => cubit.loadMore()).called(1);
  });

  testWidgets(
    'a restaurant without a photo shows a placeholder, not an error',
    (tester) async {
      await pump(
        tester,
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: [_restaurant(1)],
        ),
      );

      expect(find.byType(NetworkPhoto), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
      expect(find.text('Restaurante 1'), findsOneWidget);
    },
  );
}
