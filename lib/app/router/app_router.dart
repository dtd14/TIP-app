import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/widgets/app_button.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_state.dart';
import 'package:tip_app/features/auth/presentation/pages/login_page.dart';
import 'package:tip_app/features/auth/presentation/pages/register_page.dart';
import 'package:tip_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:tip_app/features/auth/presentation/pages/restricted_account_page.dart';
import 'package:tip_app/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:tip_app/app/presentation/main_shell.dart';
import 'package:tip_app/app/router/app_routes.dart';
import 'package:tip_app/features/notifications/presentation/widgets/notifications_session.dart';
import 'package:tip_app/app/presentation/main_shell_controller.dart';

/// Replaces the entire authentication navigator when the session changes.
/// Auth pages cannot remain behind the main screen in the back stack.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});
  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  var _mainNavigator = GlobalKey<NavigatorState>();
  Object? _authenticatedIdentity;
  bool _confirmingLogout = false;

  Future<void> _logout() async {
    if (_confirmingLogout) return;
    final bloc = context.read<AuthBloc>();
    final userId = bloc.state.user?.id;
    _confirmingLogout = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const LogoutConfirmationDialog(),
      );
      if (!mounted ||
          confirmed != true ||
          bloc.isClosed ||
          bloc.state.user?.id != userId ||
          bloc.state.status == AuthStatus.signingOut ||
          bloc.state.status == AuthStatus.unauthenticated) {
        return;
      }
      bloc.add(const AuthLogoutRequested());
    } finally {
      _confirmingLogout = false;
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (context, state) {
      switch (state.status) {
        case AuthStatus.restoring:
        case AuthStatus.signingOut:
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    state.status == AuthStatus.restoring
                        ? 'Đang kiểm tra phiên…'
                        : 'Đang đăng xuất…',
                  ),
                ],
              ),
            ),
          );
        case AuthStatus.authenticated:
          // Foreground session validation preserves open routes only while
          // the current account and all displayed permissions are unchanged.
          final user = state.user!;
          final identity = (
            user.id,
            user.accountStatus,
            user.studentId,
            user.studentStatus,
            user.studentAccessGranted,
            user.globalRole,
            user.emailVerified,
            user.hasSchoolProfile,
            user.hasCompanyProfile,
            user.schoolRole,
            user.schoolStatus,
            user.email,
            user.username,
          );
          if (_authenticatedIdentity != identity) {
            _authenticatedIdentity = identity;
            _mainNavigator = GlobalKey<NavigatorState>();
          }
          return RepositoryProvider<MainShellController>(
            key: ValueKey(user.id),
            create: (_) => MainShellController(),
            dispose: (controller) => controller.dispose(),
            child: NotificationsSession(
              key: ValueKey(identity),
              child: NavigatorPopHandler<Object?>(
                onPopWithResult: (result) =>
                    _mainNavigator.currentState!.pop(result),
                child: Navigator(
                  key: _mainNavigator,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => BlocBuilder<AuthBloc, AuthState>(
                      buildWhen: (_, current) =>
                          current.status == AuthStatus.authenticated,
                      builder: (shellContext, latest) => MainShell(
                        user: latest.user ?? state.user!,
                        onLogout: _logout,
                        controller: shellContext.read<MainShellController>(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        case AuthStatus.restricted:
          return RestrictedAccountPage(
            user: state.user,
            failure: state.failure,
            onLogout: _logout,
          );
        case AuthStatus.restoreFailed:
          return _SessionNotice(
            title: 'Chưa kiểm tra được phiên',
            message: state.failure!.message,
            buttonLabel: 'Thử lại',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthRestoreRequested()),
            secondary: TextButton(
              onPressed: _logout,
              child: const Text('Đăng xuất trên thiết bị'),
            ),
          );
        case AuthStatus.logoutFailed:
          return _SessionNotice(
            title: 'Chưa xóa được phiên',
            message: state.failure!.message,
            buttonLabel: 'Thử đăng xuất lại',
            onPressed: _logout,
          );
        case AuthStatus.unauthenticated:
          return Navigator(
            key: const ValueKey('authNavigator'),
            initialRoute: AppRoutes.login,
            onGenerateInitialRoutes: (_, initialRoute) => [
              MaterialPageRoute<String>(
                settings: const RouteSettings(name: AppRoutes.login),
                builder: (_) => LoginPage(message: state.message),
              ),
            ],
            onGenerateRoute: (settings) => MaterialPageRoute<String>(
              settings: settings,
              builder: (_) => switch (settings.name) {
                AppRoutes.register => const RegisterPage(),
                AppRoutes.verifyEmail => VerifyEmailPage(
                  arguments: settings.arguments is VerificationArguments
                      ? settings.arguments as VerificationArguments
                      : const VerificationArguments(),
                ),
                _ => LoginPage(message: state.message),
              },
            ),
          );
      }
    },
  );
}

class _SessionNotice extends StatelessWidget {
  const _SessionNotice({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.secondary,
  });
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;
  final Widget? secondary;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_outlined, size: 54),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                AppButton(label: buttonLabel, onPressed: onPressed),
                ?secondary,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
