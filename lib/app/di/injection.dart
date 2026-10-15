import 'package:tip_app/features/student_enrollment/data/datasources/student_enrollment_remote_data_source.dart';
import 'package:tip_app/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:tip_app/features/profile/data/datasources/student_profile_remote_data_source.dart';
import 'package:tip_app/features/internships/data/datasources/internship_remote_data_source.dart';
import 'package:tip_app/features/internships/data/repositories/internship_repository_impl.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/applications/data/datasources/application_remote_data_source.dart';
import 'package:tip_app/features/applications/data/repositories/application_repository_impl.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/features/opportunities/data/datasources/opportunity_remote_data_source.dart';
import 'package:tip_app/features/opportunities/data/repositories/opportunity_repository_impl.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/core/config/app_config.dart';
import 'package:tip_app/core/network/api_client.dart';
import 'package:tip_app/core/network/auth_interceptor.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'package:tip_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tip_app/features/auth/data/datasources/nest_auth_remote_data_source.dart';
import 'package:tip_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:tip_app/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:tip_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:tip_app/features/student_enrollment/data/repositories/student_enrollment_repository_impl.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/profile/data/repositories/student_profile_repository_impl.dart';
import 'package:tip_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:tip_app/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:tip_app/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:tip_app/features/notifications/domain/repositories/notification_realtime_repository.dart';
import 'package:tip_app/features/notifications/data/repositories/notification_realtime_repository_impl.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_realtime_remote_data_source.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_realtime_settings.dart';
import 'package:tip_app/features/notifications/data/datasources/notification_socket_connector.dart';

class AppDependencies {
  AppDependencies._(
    this.authRepository,
    this.apiClient,
    this.dashboardRepository,
    this.studentEnrollmentRepository,
    this.studentProfileRepository,
    this.opportunityRepository,
    this.applicationRepository,
    this.internshipRepository,
    this.notificationsRepository,
    this.notificationRealtimeRepository,
  );
  factory AppDependencies.create({
    AuthRemoteDataSource? authRemote,
    AuthRemoteDataSource Function(ApiClient)? authRemoteFactory,
    SessionStorage? sessionStorage,
    DashboardRepository? dashboardRepository,
    StudentEnrollmentRepository? studentEnrollmentRepository,
    StudentProfileRepository? studentProfileRepository,
    OpportunityRepository? opportunityRepository,
    ApplicationRepository? applicationRepository,
    InternshipRepository? internshipRepository,
    NotificationsRepository? notificationsRepository,
    NotificationRealtimeRepository? notificationRealtimeRepository,
  }) {
    if (authRemote != null && authRemoteFactory != null) {
      throw ArgumentError('Provide one auth adapter or factory, not both.');
    }
    final origin = Uri.parse(AppConfig.apiBaseUrl);
    if (origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        origin.hasQuery ||
        origin.hasFragment) {
      throw ArgumentError(
        'TIP_API_BASE_URL must be an HTTPS origin without credentials, a path prefix, query, or fragment.',
      );
    }
    late final AuthRepositoryImpl repository;
    late final ApiClient client;
    client = ApiClient(
      baseUrl: origin.origin,
      authInterceptor: AuthInterceptor(
        origin: origin,
        credential: () => repository.credential,
        onExpired: () => repository.expireSession(),
        onRefresh: (failed) => repository.refreshSession(failed),
        retryRequest: (options) => client.dio.fetch<dynamic>(options),
      ),
    );
    repository = AuthRepositoryImpl(
      remote:
          authRemoteFactory?.call(client) ??
          authRemote ??
          NestAuthRemoteDataSource(client),
      storage: sessionStorage ?? SecureSessionStorage(scope: origin.origin),
    );
    final profiles =
        studentProfileRepository ??
        StudentProfileRepositoryImpl(StudentProfileRemoteDataSource(client));
    final applicationsRemote = ApplicationRemoteDataSource(client);
    final internshipsRemote = InternshipRemoteDataSource(client);
    final applications =
        applicationRepository ?? ApplicationRepositoryImpl(applicationsRemote);
    final internships =
        internshipRepository ??
        InternshipRepositoryImpl(internshipsRemote, profiles);
    return AppDependencies._(
      repository,
      client,
      dashboardRepository ??
          DashboardRepositoryImpl(
            DashboardRemoteDataSource(profiles, applications, internships),
          ),
      studentEnrollmentRepository ??
          StudentEnrollmentRepositoryImpl(
            StudentEnrollmentRemoteDataSource(client),
          ),
      profiles,
      opportunityRepository ??
          OpportunityRepositoryImpl(OpportunityRemoteDataSource(client)),
      applications,
      internships,
      notificationsRepository ??
          NotificationsRepositoryImpl(NotificationsRemoteDataSource(client)),
      notificationRealtimeRepository ??
          NotificationRealtimeRepositoryImpl(
            NotificationRealtimeRemoteDataSource(
              NotificationsRemoteDataSource(client),
              NotificationRealtimeSettings.forOrigin(
                origin,
                socketUrl: AppConfig.notificationsSocketUrl,
                nativeOrigin: AppConfig.notificationsOrigin,
                requiresOrigin: notificationSocketRequiresOrigin,
              ),
              connectNotificationSocket,
            ),
          ),
    );
  }
  final AuthRepositoryImpl authRepository;
  final DashboardRepository dashboardRepository;
  final StudentEnrollmentRepository studentEnrollmentRepository;
  final StudentProfileRepository studentProfileRepository;
  final OpportunityRepository opportunityRepository;
  final ApplicationRepository applicationRepository;
  final InternshipRepository internshipRepository;
  final NotificationsRepository notificationsRepository;
  final NotificationRealtimeRepository notificationRealtimeRepository;

  /// Shared client used by the production NestJS adapter and protected requests.
  final ApiClient apiClient;
  Future<void> dispose() async {
    await notificationRealtimeRepository.dispose();
    apiClient.close();
    await authRepository.dispose();
  }
}
