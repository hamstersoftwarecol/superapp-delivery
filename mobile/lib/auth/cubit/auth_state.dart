part of 'auth_cubit.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.error,
  });

  final AuthStatus status;
  final User? user;
  final bool isSubmitting;
  final String? error;

  AuthState copyWith({
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) => AuthState(
    status: status,
    user: user,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [status, user, isSubmitting, error];
}
