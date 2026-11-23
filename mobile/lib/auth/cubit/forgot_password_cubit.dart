import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';

part 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const ForgotPasswordState());

  final AuthRepository _authRepository;

  Future<void> submit(String email) async {
    if (state.status == ForgotPasswordStatus.submitting) return;

    emit(const ForgotPasswordState(status: ForgotPasswordStatus.submitting));
    try {
      final message = await _authRepository.forgotPassword(email: email);
      emit(
        ForgotPasswordState(
          status: ForgotPasswordStatus.sent,
          message: message,
        ),
      );
    } on Object catch (error) {
      emit(
        ForgotPasswordState(
          status: ForgotPasswordStatus.failure,
          message: errorMessage(error),
        ),
      );
    }
  }
}
