import 'dart:async';

import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState()) {
    _userSubscription = _authRepository.user.listen(_onUserChanged);
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<User?> _userSubscription;

  /// Restores the previous session, if any.
  Future<void> started() async {
    try {
      _onUserChanged(await _authRepository.restoreSession());
    } on ApiException catch (error) {
      // Offline at startup: keep the token, ask the user to sign in again
      // only if the server later rejects it.
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          error: error.displayMessage,
        ),
      );
    }
  }

  Future<void> login({required String email, required String password}) =>
      _submit(() => _authRepository.login(email: email, password: password));

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) => _submit(
    () => _authRepository.register(
      name: name,
      email: email,
      password: password,
      role: role,
      phone: phone,
    ),
  );

  /// Re-reads the account, e.g. to find out an admin approved it.
  Future<void> refresh() async {
    try {
      await _authRepository.refreshUser();
    } on Object catch (error) {
      emit(state.copyWith(error: errorMessage(error)));
    }
  }

  Future<void> logout() => _authRepository.logout();

  Future<void> _submit(Future<User> Function() action) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await action();
    } on Object catch (error) {
      emit(state.copyWith(isSubmitting: false, error: errorMessage(error)));
    }
  }

  void _onUserChanged(User? user) {
    emit(
      AuthState(
        status: user == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        user: user,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _userSubscription.cancel();
    return super.close();
  }
}
