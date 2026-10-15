import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_event.dart';
import 'package:tip_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/app/di/injection.dart';
import 'package:tip_app/app/router/app_router.dart';
import 'package:tip_app/app/theme/app_theme.dart';
import 'package:tip_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:tip_app/features/notifications/domain/repositories/notification_realtime_repository.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.dependencies});
  final AppDependencies? dependencies;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppDependencies _dependencies;
  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ?? AppDependencies.create();
  }

  @override
  void dispose() {
    if (widget.dependencies == null) unawaited(_dependencies.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<NotificationRealtimeRepository>.value(
        value: _dependencies.notificationRealtimeRepository,
      ),
      RepositoryProvider<NotificationsRepository>.value(
        value: _dependencies.notificationsRepository,
      ),
      RepositoryProvider<InternshipRepository>.value(
        value: _dependencies.internshipRepository,
      ),
      RepositoryProvider<ApplicationRepository>.value(
        value: _dependencies.applicationRepository,
      ),
      RepositoryProvider<OpportunityRepository>.value(
        value: _dependencies.opportunityRepository,
      ),
      RepositoryProvider<AuthRepository>.value(
        value: _dependencies.authRepository,
      ),
      RepositoryProvider<DashboardRepository>.value(
        value: _dependencies.dashboardRepository,
      ),
      RepositoryProvider<StudentEnrollmentRepository>.value(
        value: _dependencies.studentEnrollmentRepository,
      ),
      RepositoryProvider<StudentProfileRepository>.value(
        value: _dependencies.studentProfileRepository,
      ),
    ],
    child: BlocProvider(
      create: (context) =>
          AuthBloc(context.read<AuthRepository>())
            ..add(const AuthRestoreRequested()),
      child: MaterialApp(
        title: 'TIP Career',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppRouter(),
      ),
    ),
  );
}
