import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/auth/auth.dart';

/// Shown to couriers whose account an admin has not approved yet.
class PendingApprovalView extends StatefulWidget {
  const PendingApprovalView({super.key});

  @override
  State<PendingApprovalView> createState() => _PendingApprovalViewState();
}

class _PendingApprovalViewState extends State<PendingApprovalView> {
  bool _checking = false;

  Future<void> _check() async {
    final cubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    setState(() => _checking = true);
    await cubit.refresh();

    // Approved: this screen is about to be replaced, so make sure no
    // "still reviewing" notice from an earlier tap is left on the next one.
    if (!(cubit.state.user?.isPending ?? false)) {
      messenger.hideCurrentSnackBar();
    }
    if (!mounted) return;
    setState(() => _checking = false);

    if (cubit.state.user?.isPending ?? false) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Todavía estamos revisando tu cuenta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Tu cuenta está en revisión',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Un administrador revisará tus datos antes de que puedas '
                'tomar pedidos. Vuelve a abrir la app más tarde o toca el '
                'botón para ver si ya te aprobaron.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _checking ? null : _check,
                child: _checking
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Revisar estado'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
