import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/auth/auth.dart';

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late _MockAuthCubit cubit;

  setUp(() {
    cubit = _MockAuthCubit();
    when(() => cubit.state).thenReturn(const AuthState());
  });

  Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AuthCubit>.value(
        value: cubit,
        child: const LoginPage(),
      ),
    ),
  );

  testWidgets('validates the fields before calling the cubit', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
    verifyNever(
      () => cubit.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('submits the trimmed email and the password', (tester) async {
    when(
      () => cubit.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    await pumpLogin(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      '  ana@example.test ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secret-pass',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    verify(
      () => cubit.login(email: 'ana@example.test', password: 'secret-pass'),
    ).called(1);
  });

  testWidgets('shows the error from the cubit', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const AuthState(error: 'Las credenciales no son correctas.'));
    await pumpLogin(tester);

    expect(find.text('Las credenciales no son correctas.'), findsOneWidget);
  });
}
