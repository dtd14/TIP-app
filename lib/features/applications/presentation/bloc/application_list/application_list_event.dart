import 'dart:async';

sealed class ApplicationListEvent {
  final Completer<void> completion = Completer<void>();
}

class ApplicationListLoadRequested extends ApplicationListEvent {
  ApplicationListLoadRequested({this.reset = false});
  final bool reset;
}

class ApplicationListFilterChanged extends ApplicationListEvent {
  ApplicationListFilterChanged(this.status);
  final String? status;
}
