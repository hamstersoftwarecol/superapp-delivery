import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/auth/auth.dart';
import 'package:superapp_delivery/home/view/pending_approval_view.dart';

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

const _pendingCourier = User(
  id: 1,
  name: 'Rafa',
  email: 'rafa@example.test',
  role: UserRole.courier,
  status: AccountStatus.pending,
);

void main() {
  late _MockAuthCubit cubit;

  setUp(() {
    cubit = _MockAuthCubit();
    when(() => cubit.state).thenReturn(
      const AuthState(status: AuthStatus.authenticated, user: _pendingCourier),
    );
    when(() => cubit.refresh()).thenAnswer((_) async {});
  });

  Future<void> pumpView(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AuthCubit>.value(
        value: cubit,
        child: const PendingApprovalView(),
      ),
    ),
  );

  testWidgets('explains that the account is under review', (tester) async {
    await pumpView(tester);

    expect(find.text('Tu cuenta está en revisión'), findsOneWidget);
    expect(find.text('Revisar estado'), findsOneWidget);
  });

  testWidgets('asks the server again and says when nothing changed', (
    tester,
  ) async {
    await pumpView(tester);

    await tester.tap(find.text('Revisar estado'));
    await tester.pump();
    await tester.pump();

    verify(() => cubit.refresh()).called(1);
    expect(find.text('Todavía estamos revisando tu cuenta.'), findsOneWidget);
  });

  testWidgets('does not nag once the account was approved', (tester) async {
    when(() => cubit.refresh()).thenAnswer((_) async {
      when(() => cubit.state).thenReturn(
        const AuthState(
          status: AuthStatus.authenticated,
          user: User(
            id: 1,
            name: 'Rafa',
            email: 'rafa@example.test',
            role: UserRole.courier,
          ),
        ),
      );
    });
    await pumpView(tester);

    await tester.tap(find.text('Revisar estado'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Todavía estamos revisando tu cuenta.'), findsNothing);
  });

  testWidgets('lets the user sign out', (tester) async {
    when(() => cubit.logout()).thenAnswer((_) async {});
    await pumpView(tester);

    await tester.tap(find.byTooltip('Cerrar sesión'));

    verify(() => cubit.logout()).called(1);
  });
}
