part of 'forgot_password_cubit.dart';

enum ForgotPasswordStatus { initial, submitting, sent, failure }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.status = ForgotPasswordStatus.initial,
    this.message,
  });

  final ForgotPasswordStatus status;

  /// What the server answered, or why the request failed.
  final String? message;

  @override
  List<Object?> get props => [status, message];
}
