import 'dart:async';

sealed class PlacementDetailEvent {
  final Completer<void> completion = Completer<void>();
}

class PlacementLoadRequested extends PlacementDetailEvent {
  PlacementLoadRequested();
}

class PlacementCompanyLoadRequested extends PlacementDetailEvent {
  PlacementCompanyLoadRequested(this.id);
  final String id;
}
