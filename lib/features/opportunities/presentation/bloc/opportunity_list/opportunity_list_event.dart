import 'dart:async';

sealed class OpportunityListEvent {
  final Completer<void> completion = Completer<void>();
}

class OpportunityListLoadRequested extends OpportunityListEvent {
  OpportunityListLoadRequested({this.reset = false});
  final bool reset;
}
