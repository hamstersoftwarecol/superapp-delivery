import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/auth/auth.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/orders/orders.dart';

class _MockOrderDetailCubit extends MockCubit<OrderDetailState>
    implements OrderDetailCubit {}

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

const _courier = User(
  id: 9,
  name: 'Rafa',
  email: 'rafa@example.test',
  role: UserRole.courier,
);

const _customer = User(
  id: 4,
  name: 'Ana',
  email: 'ana@example.test',
  role: UserRole.customer,
);

Order _order(
  OrderStatus status, {
  User? courier,
  String? reason,
  OrderActor? actor,
}) => Order(
  id: 5,
  status: status,
  subtotalCents: 100,
  deliveryFeeCents: 10,
  totalCents: 110,
  deliveryAddress: 'Calle 1',
  createdAt: DateTime(2026, 11, 23),
  courier: courier,
  statusReason: reason,
  statusActor: actor,
);

void main() {
  late _MockOrderDetailCubit orderCubit;
  late _MockAuthCubit authCubit;

  setUpAll(() => registerFallbackValue(OrderStatus.failed));

  setUp(() {
    orderCubit = _MockOrderDetailCubit();
    authCubit = _MockAuthCubit();
    when(() => orderCubit.updateStatus(any(), reason: any(named: 'reason')))
        .thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, Order order, User user) {
    when(() => orderCubit.state)
        .thenReturn(OrderDetailState(status: LoadStatus.success, order: order));
    when(() => authCubit.state)
        .thenReturn(AuthState(status: AuthStatus.authenticated, user: user));

    return tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<OrderDetailCubit>.value(value: orderCubit),
            BlocProvider<AuthCubit>.value(value: authCubit),
          ],
          child: const OrderDetailView(),
        ),
      ),
    );
  }

  group('unhappy endings', () {
    testWidgets('show who decided and why', (tester) async {
      await pump(
        tester,
        _order(
          OrderStatus.cancelled,
          reason: 'Se agotaron los ingredientes.',
          actor: OrderActor.restaurant,
        ),
        _customer,
      );

      expect(find.text('Cancelado por el restaurante'), findsOneWidget);
      expect(
        find.text('Motivo: Se agotaron los ingredientes.'),
        findsOneWidget,
      );
    });

    testWidgets('a delivery that failed shows the courier\'s reason', (
      tester,
    ) async {
      await pump(
        tester,
        _order(
          OrderStatus.failed,
          reason: 'El cliente no contestó',
          actor: OrderActor.courier,
        ),
        _customer,
      );

      expect(find.text('No se pudo entregar'), findsOneWidget);
      expect(find.text('Motivo: El cliente no contestó'), findsOneWidget);
    });
  });

  group('courier actions', () {
    testWidgets('can give back an order they have not picked up', (
      tester,
    ) async {
      await pump(
        tester,
        _order(OrderStatus.ready, courier: _courier),
        _courier,
      );

      expect(find.text('Recogí el pedido'), findsOneWidget);
      expect(find.text('Soltar pedido'), findsOneWidget);
      expect(find.text('No pude entregarlo'), findsNothing);
    });

    testWidgets('can report a failed delivery with a preset reason', (
      tester,
    ) async {
      await pump(
        tester,
        _order(OrderStatus.pickedUp, courier: _courier),
        _courier,
      );

      await tester.tap(find.text('No pude entregarlo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      verify(
        () => orderCubit.updateStatus(
          OrderStatus.failed,
          reason: 'El cliente no contestó',
        ),
      ).called(1);
    });

    testWidgets('must write a reason when choosing "Otro"', (tester) async {
      await pump(
        tester,
        _order(OrderStatus.pickedUp, courier: _courier),
        _courier,
      );

      await tester.tap(find.text('No pude entregarlo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otro').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el motivo'), findsOneWidget);
      verifyNever(
        () => orderCubit.updateStatus(any(), reason: any(named: 'reason')),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'Había un portón cerrado',
      );
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      verify(
        () => orderCubit.updateStatus(
          OrderStatus.failed,
          reason: 'Había un portón cerrado',
        ),
      ).called(1);
    });

    testWidgets('closing the dialog reports nothing', (tester) async {
      await pump(
        tester,
        _order(OrderStatus.pickedUp, courier: _courier),
        _courier,
      );

      await tester.tap(find.text('No pude entregarlo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      verifyNever(
        () => orderCubit.updateStatus(any(), reason: any(named: 'reason')),
      );
    });

    testWidgets('another courier gets no actions', (tester) async {
      await pump(
        tester,
        _order(OrderStatus.ready, courier: _courier),
        const User(
          id: 10,
          name: 'Otro',
          email: 'otro@example.test',
          role: UserRole.courier,
        ),
      );

      expect(find.text('Recogí el pedido'), findsNothing);
      expect(find.text('Soltar pedido'), findsNothing);
    });
  });
}
