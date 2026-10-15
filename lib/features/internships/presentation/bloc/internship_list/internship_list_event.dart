import 'dart:async';

sealed class InternshipListEvent {
  final Completer<void> completion = Completer<void>();
}

class InternshipListLoadRequested extends InternshipListEvent {
  InternshipListLoadRequested();
}

class InternshipListNextPageRequested extends InternshipListEvent {
  InternshipListNextPageRequested({this.reset = false});
  final bool reset;
}

class InternshipRegistrationFilterChanged extends InternshipListEvent {
  InternshipRegistrationFilterChanged(this.filter);
  final String filter;
}

class InternshipMoreRegistrationsRequested extends InternshipListEvent {}
