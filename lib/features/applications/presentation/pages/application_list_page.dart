import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_list/application_list_state.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_list/application_list_event.dart';
import 'package:tip_app/features/applications/presentation/bloc/application_list/application_list_bloc.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/applications/domain/entities/application_overview.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/date_formatter.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';
import 'package:tip_app/features/applications/presentation/widgets/application_ui.dart';
import 'package:tip_app/features/applications/presentation/pages/application_detail_page.dart';
import 'package:tip_app/features/opportunities/presentation/company_navigation.dart';

class ApplicationListPage extends StatefulWidget {
  const ApplicationListPage({
    super.key,
    required this.repository,
    required this.user,
    required this.onRestricted,
    required this.onChanged,
  });
  final ApplicationRepository repository;
  final AuthUser user;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback onChanged;
  @override
  State<ApplicationListPage> createState() => _ApplicationListPageState();
}

class _ApplicationListPageState extends State<ApplicationListPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = ApplicationListBloc(widget.repository);
  List<ApplicationOverview> get _items => _bloc.state.items;
  PageSlice<ApplicationOverview>? get _page => _bloc.state.page;
  AuthFailure? get _failure => _bloc.state.failure;
  bool get _loading => _bloc.state.loading;
  bool get _retryReset => _bloc.state.retryReset;
  String? get _status => _bloc.state.status;
  Future<void> _load({bool reset = false}) =>
      _bloc.dispatch(ApplicationListLoadRequested(reset: reset));
  Future<void> _filter(String? status) =>
      _bloc.dispatch(ApplicationListFilterChanged(status));
  void _onBlocState(BuildContext context, ApplicationListState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ApplicationListBloc, ApplicationListState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<ApplicationListBloc, ApplicationListState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  final _companies = CompanyNavigation();
  Future<void> _company(ApplicationOverview item) async {
    if (_companies.isOpening) return;
    var changed = false;
    await _companies.open(
      context,
      companyId: item.companyId,
      applicationId: item.id,
      onRestricted: widget.onRestricted,
      onChanged: () => changed = true,
    );
    if (!mounted) return;
    if (changed) widget.onChanged();
    // A send from the company page can have an uncertain response. Read the
    // current list on return even when a successful write was not reported.
    await _load(reset: true);
  }

  bool _opening = false;
  static const _filters = <String?, String>{
    null: 'Tất cả',
    'PENDING': 'Chờ duyệt',
    'REVIEWING': 'Đang xem xét',
    'ACCEPTED': 'Được nhận',
    'REJECTED': 'Chưa phù hợp',
    'WITHDRAWN': 'Đã rút',
  };
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _open(ApplicationOverview item) async {
    if (_opening) return;
    _opening = true;
    var changed = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicationDetailPage(
          application: item,
          user: widget.user,
          repository: widget.repository,
          onRestricted: widget.onRestricted,
          onChanged: () => changed = true,
        ),
      ),
    );
    _opening = false;
    if (mounted && changed) {
      widget.onChanged();
      await _load(reset: true);
    }
  }

  Widget _buildContent(BuildContext context) => DashboardScroll(
    onRefresh: () => _load(reset: true),
    children: [
      const Text(
        'Đơn ứng tuyển của tôi',
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Theo dõi trạng thái và xem thông tin từng đơn ứng tuyển.',
        style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
      ),
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('applicationFilter-${entry.key ?? 'ALL'}'),
                    label: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _status == entry.key,
                    onSelected: _loading ? null : (_) => _filter(entry.key),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _status == entry.key
                          ? Colors.white
                          : AppColors.text,
                    ),
                    showCheckmark: false,
                    side: BorderSide.none,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 12),
      if (_page != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${_page!.total} đơn ứng tuyển',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      if (_failure != null) ...[
        DashboardPanel(
          child: Column(
            children: [
              Text(_failure!.message, textAlign: TextAlign.center),
              TextButton(
                onPressed: _loading ? null : () => _load(reset: _retryReset),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        ),
      if (!_loading && _failure == null && _items.isEmpty)
        const DashboardPanel(
          child: DashboardEmpty(
            'Bạn chưa có đơn ứng tuyển phù hợp với bộ lọc.',
          ),
        ),
      ..._items.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            key: Key('application-${item.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _open(item),
            child: DashboardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => _open(item),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CompanyAvatar(
                          name: item.company,
                          size: 38,
                          onTap: () => _company(item),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CompanyName(
                                item.company,
                                fontSize: 11,
                                verified: item.companyVerified,
                                onTap: () => _company(item),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(
                        item.statusLabel,
                        color: applicationStatusColor(item.status),
                      ),
                      if (item.type != null)
                        StatusPill(
                          applicationTypeLabel(item.type),
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Nộp: ${DateFormatter.date(item.appliedAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        if (item.updatedAt != null)
                          Text(
                            'Cập nhật: ${DateFormatter.date(item.updatedAt!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    applicationStatusMessage(item.status),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: Key('applicationDetails-${item.id}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: () => _open(item),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text(
                        'Xem chi tiết',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_page?.hasNext == true && !_loading && _failure == null)
        OutlinedButton(onPressed: _load, child: const Text('Tải thêm đơn')),
    ],
  );
}
