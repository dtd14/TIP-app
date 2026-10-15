import 'dart:async';

sealed class CompanyDetailEvent {
  final Completer<void> completion = Completer<void>();
}

class CompanyRefreshRequested extends CompanyDetailEvent {
  CompanyRefreshRequested();
}

class CompanyLoadRequested extends CompanyDetailEvent {
  CompanyLoadRequested();
}

class CompanyOpportunitiesLoadRequested extends CompanyDetailEvent {
  CompanyOpportunitiesLoadRequested();
}

class CompanyMoreOpportunitiesRequested extends CompanyDetailEvent {}
