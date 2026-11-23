import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/auth/auth.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
    when(() => repository.user).thenAnswer((_) => const Stream.empty());
  });

  group('ForgotPasswordCubit', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'shows the server message once the email is sent',
      setUp: () =>
          when(() => repository.forgotPassword(email: 'ana@example.test'))
              .thenAnswer((_) async => 'Revisa tu correo'),
      build: () => ForgotPasswordCubit(authRepository: repository),
      act: (cubit) => cubit.submit('ana@example.test'),
      expect: () => const [
        ForgotPasswordState(status: ForgotPasswordStatus.submitting),
        ForgotPasswordState(
          status: ForgotPasswordStatus.sent,
          message: 'Revisa tu correo',
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'reports why it failed so the user can retry',
      setUp: () =>
          when(() => repository.forgotPassword(email: any(named: 'email')))
              .thenThrow(const ApiException(429, 'Demasiados intentos.')),
      build: () => ForgotPasswordCubit(authRepository: repository),
      act: (cubit) => cubit.submit('ana@example.test'),
      expect: () => const [
        ForgotPasswordState(status: ForgotPasswordStatus.submitting),
        ForgotPasswordState(
          status: ForgotPasswordStatus.failure,
          message: 'Demasiados intentos.',
        ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'ignores a second tap while the first request is running',
      setUp: () =>
          when(() => repository.forgotPassword(email: any(named: 'email')))
              .thenAnswer((_) async => 'ok'),
      build: () => ForgotPasswordCubit(authRepository: repository),
      act: (cubit) {
        cubit
          ..submit('ana@example.test')
          ..submit('ana@example.test');
      },
      verify: (_) =>
          verify(() => repository.forgotPassword(email: any(named: 'email')))
              .called(1),
    );
  });
}
