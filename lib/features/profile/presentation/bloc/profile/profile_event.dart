import 'dart:async';

sealed class ProfileEvent {
  final Completer<void> completion = Completer<void>();
}

class ProfileLoadRequested extends ProfileEvent {
  ProfileLoadRequested();
}
