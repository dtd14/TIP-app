import 'dart:async';

sealed class ApplicationDetailEvent {
  final Completer<void> completion = Completer<void>();
}

class ApplicationDetailLoadRequested extends ApplicationDetailEvent {
  ApplicationDetailLoadRequested();
}

class ApplicationWithdrawalRequested extends ApplicationDetailEvent {
  ApplicationWithdrawalRequested();
}
