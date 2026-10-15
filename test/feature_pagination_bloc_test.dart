import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_list/opportunity_list_bloc.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_list/opportunity_list_event.dart';
import 'support/dashboard_fixtures.dart';

OpportunityOverview opportunity(String id, {String title = 'Intern'}) =>
    OpportunityOverview(
      id: id,
      title: title,
      company: 'TIP',
      type: 'INTERNSHIP',
      description: 'Description',
    );

PageSlice<OpportunityOverview> page(
  int number,
  List<OpportunityOverview> items, {
  int total = 3,
}) => PageSlice(items: items, total: total, page: number, limit: 2);

void main() {
  test('failed append retries its page and preserves earlier items', () async {
    var fail = true;
    final repository = FakeDashboardRepository()
      ..onOpportunities = (number) async {
        if (number == 1) return page(1, [opportunity('a'), opportunity('b')]);
        if (fail) throw const AuthFailure(FailureKind.network, 'Offline');
        return page(2, [opportunity('b', title: 'Updated'), opportunity('c')]);
      };
    final bloc = OpportunityListBloc(repository);
    addTearDown(bloc.close);
    await bloc.dispatch(OpportunityListLoadRequested(reset: true));
    await bloc.dispatch(OpportunityListLoadRequested());
    expect(bloc.state.items.map((item) => item.id), ['a', 'b']);
    expect(bloc.state.page!.page, 1);
    expect(bloc.state.retryReset, false);
    fail = false;
    await bloc.dispatch(
      OpportunityListLoadRequested(reset: bloc.state.retryReset),
    );
    expect(repository.opportunityPages, [1, 2, 2]);
    expect(bloc.state.items.map((item) => item.id), ['a', 'b', 'c']);
    expect(bloc.state.items[1].title, 'Updated');
    expect(bloc.state.failure, isNull);
    expect(() => bloc.state.items.clear(), throwsUnsupportedError);
    await bloc.dispatch(OpportunityListLoadRequested());
    expect(repository.opportunityPages, [1, 2, 2]);
  });

  test('refresh replaces the list and resets pagination metadata', () async {
    final repository = FakeDashboardRepository()
      ..onOpportunities = (number) async =>
          page(number, [opportunity('$number')]);
    final bloc = OpportunityListBloc(repository);
    addTearDown(bloc.close);
    await bloc.dispatch(OpportunityListLoadRequested(reset: true));
    await bloc.dispatch(OpportunityListLoadRequested());
    repository.onOpportunities = (_) async =>
        page(1, [opportunity('new')], total: 1);
    await bloc.dispatch(OpportunityListLoadRequested(reset: true));
    expect(bloc.state.items.single.id, 'new');
    expect(bloc.state.page!.page, 1);
    expect(bloc.state.page!.hasNext, false);
  });

  test('repeated requests do not start another pending page load', () async {
    final pending = Completer<PageSlice<OpportunityOverview>>();
    final repository = FakeDashboardRepository()
      ..onOpportunities = (_) => pending.future;
    final bloc = OpportunityListBloc(repository);
    addTearDown(bloc.close);
    final first = bloc.dispatch(OpportunityListLoadRequested(reset: true));
    await bloc.stream.firstWhere((state) => state.loading);
    await bloc.dispatch(OpportunityListLoadRequested(reset: true));
    expect(repository.opportunityPages, [1]);
    pending.complete(page(1, [opportunity('a')], total: 1));
    await first;
    expect(bloc.state.loading, false);
    expect(bloc.state.items.single.id, 'a');
  });

  test('a pending response does not emit after the Bloc is closed', () async {
    final pending = Completer<PageSlice<OpportunityOverview>>();
    final repository = FakeDashboardRepository()
      ..onOpportunities = (_) => pending.future;
    final bloc = OpportunityListBloc(repository);
    final first = bloc.dispatch(OpportunityListLoadRequested(reset: true));
    await bloc.stream.firstWhere((state) => state.loading);
    final closing = bloc.close();
    pending.complete(page(1, [opportunity('a')], total: 1));
    await Future.wait([first, closing]);
    expect(bloc.state.items, isEmpty);
  });
}
