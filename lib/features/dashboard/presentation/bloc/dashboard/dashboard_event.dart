import 'dart:async';

sealed class DashboardEvent {}

class DashboardRefreshRequested extends DashboardEvent {
  final Completer<void> completion = Completer<void>();
}
