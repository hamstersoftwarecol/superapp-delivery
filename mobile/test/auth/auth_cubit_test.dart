import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/auth/auth.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = User(
  id: 1,
  name: 'Ana',
  email: 'ana@example.test',
  role: UserRole.customer,
);

void main() {
  late _MockAuthRepository repository;
  late StreamController<User?> users;

  setUp(() {
    repository = _MockAuthRepository();
    users = StreamController<User?>.broadcast();
    when(() => repository.user).thenAnswer((_) => users.stream);
  });

  tearDown(() => users.close());

  group('AuthCubit', () {
    blocTest<AuthCubit, AuthState>(
      'started signs in a restored session',
      setUp: () =>
          when(() => repository.restoreSession())
              .thenAnswer((_) async => _user),
      build: () => AuthCubit(authRepository: repository),
      act: (cubit) => cubit.started(),
      expect: () => [
        const AuthState(status: AuthStatus.authenticated, user: _user),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'started without a session goes to unauthenticated',
      setUp: () =>
          when(() => repository.restoreSession()).thenAnswer((_) async => null),
      build: () => AuthCubit(authRepository: repository),
      act: (cubit) => cubit.started(),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
    );

    blocTest<AuthCubit, AuthState>(
      'a failed login keeps the user signed out and shows the error',
      setUp: () =>
          when(
            () => repository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(
            const ApiException(
              422,
              'x',
              fieldErrors: {
                'email': ['Credenciales incorrectas'],
              },
            ),
          ),
      build: () => AuthCubit(authRepository: repository),
      act: (cubit) => cubit.login(email: 'a@b.c', password: 'nope'),
      expect: () => [
        const AuthState(isSubmitting: true),
        const AuthState(error: 'Credenciales incorrectas'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'follows the repository when the session ends elsewhere',
      build: () => AuthCubit(authRepository: repository),
      act: (cubit) {
        users
          ..add(_user)
          ..add(null);
      },
      expect: () => [
        const AuthState(status: AuthStatus.authenticated, user: _user),
        const AuthState(status: AuthStatus.unauthenticated),
      ],
    );
  });
}
