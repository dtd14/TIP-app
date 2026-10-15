import '../../domain/entities/notification_realtime_event.dart';
import '../../domain/repositories/notification_realtime_repository.dart';
import '../datasources/notification_realtime_remote_data_source.dart';

class NotificationRealtimeRepositoryImpl
    implements NotificationRealtimeRepository {
  const NotificationRealtimeRepositoryImpl(this.remote);
  final NotificationRealtimeRemoteDataSource remote;
  @override
  Stream<NotificationRealtimeEvent> watch() => remote.watch();
  @override
  Future<void> dispose() => remote.dispose();
}
