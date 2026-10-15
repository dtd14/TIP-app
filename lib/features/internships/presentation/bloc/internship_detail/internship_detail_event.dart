import 'dart:async';

sealed class InternshipDetailEvent {
  final Completer<void> completion = Completer<void>();
}

class InternshipDetailLoadRequested extends InternshipDetailEvent {
  InternshipDetailLoadRequested();
}

class InternshipDetailNextPageRequested extends InternshipDetailEvent {
  InternshipDetailNextPageRequested({this.reset = false});
  final bool reset;
}
