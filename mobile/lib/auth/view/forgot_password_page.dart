import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/auth/cubit/forgot_password_cubit.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ForgotPasswordCubit(authRepository: context.read<AuthRepository>()),
      child: const ForgotPasswordView(),
    );
  }
}

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ForgotPasswordCubit>().submit(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                builder: (context, state) {
                  if (state.status == ForgotPasswordStatus.sent) {
                    return _SentView(message: state.message!);
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Escribe el correo de tu cuenta y te enviaremos un '
                          'enlace para crear una contraseña nueva.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                          ),
                          validator: (value) => (value ?? '').contains('@')
                              ? null
                              : 'Escribe un correo válido',
                        ),
                        if (state.status == ForgotPasswordStatus.failure) ...[
                          const SizedBox(height: 16),
                          Text(
                            state.message ?? '',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed:
                              state.status == ForgotPasswordStatus.submitting
                              ? null
                              : _submit,
                          child: state.status == ForgotPasswordStatus.submitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Enviar instrucciones'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Abre el enlace del correo, crea tu contraseña nueva y vuelve aquí '
          'para iniciar sesión. Si no lo ves, revisa la carpeta de correo no '
          'deseado.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    );
  }
}
