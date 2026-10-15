import 'dart:async';

sealed class OpportunityDetailEvent {
  final Completer<void> completion = Completer<void>();
}

class OpportunityDetailLoadRequested extends OpportunityDetailEvent {
  OpportunityDetailLoadRequested();
}

class OpportunityCompanyLoadRequested extends OpportunityDetailEvent {
  OpportunityCompanyLoadRequested(this.id);
  final String id;
}
