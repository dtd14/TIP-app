import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_list/opportunity_list_state.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_list/opportunity_list_event.dart';
import 'package:tip_app/features/opportunities/presentation/bloc/opportunity_list/opportunity_list_bloc.dart';
import 'package:tip_app/core/domain/entities/page_slice.dart';
import 'package:tip_app/features/opportunities/domain/entities/opportunity_overview.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/opportunities/presentation/widgets/opportunity_ui.dart';
import 'package:tip_app/features/opportunities/presentation/pages/opportunity_detail_page.dart';
import 'package:tip_app/features/opportunities/presentation/company_navigation.dart';

const _types = <String?, String>{
  null: 'Tất cả',
  'INTERNSHIP': 'Thực tập',
  'MICRO_INTERNSHIP': 'Thực tập ngắn hạn',
  'JOB': 'Việc làm',
};
typedef _FilterSelection = ({String? type, String location});

class OpportunityListPage extends StatefulWidget {
  const OpportunityListPage({
    super.key,
    required this.repository,
    required this.onRestricted,
    this.canApply = false,
    this.onApplied,
    this.onViewApplications,
  });
  final OpportunityRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final bool canApply;
  final VoidCallback? onApplied;
  final VoidCallback? onViewApplications;
  @override
  State<OpportunityListPage> createState() => _OpportunityListPageState();
}

class _OpportunityListPageState extends State<OpportunityListPage> {
  late final _bloc = OpportunityListBloc(widget.repository);
  List<OpportunityOverview> get _items => _bloc.state.items;
  PageSlice<OpportunityOverview>? get _page => _bloc.state.page;
  AuthFailure? get _failure => _bloc.state.failure;
  bool get _loading => _bloc.state.loading;
  bool get _retryReset => _bloc.state.retryReset;
  Future<void> _load({bool reset = false}) =>
      _bloc.dispatch(OpportunityListLoadRequested(reset: reset));
  void _onBlocState(BuildContext context, OpportunityListState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<OpportunityListBloc, OpportunityListState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<OpportunityListBloc, OpportunityListState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  final _search = TextEditingController();
  final _companies = CompanyNavigation();
  bool _deadlineFirst = false;
  String? _type;
  String _location = '';
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _bloc.close();
    _search.dispose();
    super.dispose();
  }

  Future<void> _filters() async {
    final result = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _OpportunityFilters(type: _type, location: _location),
    );
    if (mounted && result != null) {
      setState(() {
        _type = result.type;
        _location = result.location;
      });
    }
  }

  Future<void> _details(OpportunityOverview item) async {
    FocusScope.of(context).unfocus();
    var applied = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OpportunityDetailPage(
          opportunity: item,
          repository: widget.repository,
          canApply: widget.canApply,
          onRestricted: widget.onRestricted,
          onApplied: () => applied = true,
          onViewApplications: widget.onViewApplications,
        ),
      ),
    );
    if (mounted && applied) widget.onApplied?.call();
  }

  Widget _buildContent(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _items
        .where(
          (item) =>
              (_type == null || item.type == _type) &&
              (_location.isEmpty ||
                  (item.location ?? '').toLowerCase().contains(
                    _location.toLowerCase(),
                  )) &&
              (query.isEmpty ||
                  '${item.title} ${item.company} ${item.description} ${item.location ?? ''}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    if (_deadlineFirst) {
      filtered.sort((a, b) {
        if (a.deadline == null) return b.deadline == null ? 0 : 1;
        if (b.deadline == null) return -1;
        return a.deadline!.compareTo(b.deadline!);
      });
    }
    final filtering = query.isNotEmpty || _type != null || _location.isNotEmpty;
    return DashboardScroll(
      onRefresh: () => _load(reset: true),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('opportunitySearch'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Vị trí, công ty, địa điểm',
                  hintStyle: const TextStyle(fontSize: 13),
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.muted,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Badge(
              isLabelVisible: _type != null || _location.isNotEmpty,
              backgroundColor: const Color(0xFF52D4E9),
              child: IconButton.filled(
                tooltip: 'Lọc cơ hội',
                onPressed: _filters,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size(50, 52),
                ),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _types.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('opportunityType-${entry.key ?? 'ALL'}'),
                      showCheckmark: false,
                      label: Text(
                        entry.key == null && _page != null
                            ? 'Tất cả ${_page!.total}'
                            : entry.value,
                      ),
                      selected: _type == entry.key,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      labelStyle: TextStyle(
                        color: _type == entry.key
                            ? Colors.white
                            : AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _type = entry.key),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (_location.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text(_location),
              avatar: const Icon(Icons.location_on_outlined, size: 16),
              onDeleted: () => setState(() => _location = ''),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 17,
              color: AppColors.accent,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                filtering
                    ? '${filtered.length} kết quả trong ${_items.length} cơ hội đã tải'
                    : 'Đã tải ${_items.length}/${_page?.total ?? 0} cơ hội',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            PopupMenuButton<bool>(
              tooltip: 'Sắp xếp cơ hội đã tải',
              initialValue: _deadlineFirst,
              onSelected: (value) => setState(() => _deadlineFirst = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('Mới nhất')),
                PopupMenuItem(value: true, child: Text('Hạn gần nhất')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _deadlineFirst ? 'Hạn gần nhất' : 'Mới nhất',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          const SizedBox(height: 14),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading && _failure == null && filtered.isEmpty)
          DashboardPanel(
            child: DashboardEmpty(
              filtering
                  ? 'Chưa tìm thấy cơ hội phù hợp trong danh sách đã tải.\nThử đổi bộ lọc hoặc tải thêm cơ hội.'
                  : 'Hiện chưa có cơ hội đang mở.\nHãy quay lại sau nhé.',
              icon: Icons.search_off_rounded,
            ),
          ),
        ...filtered.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OpportunityCard(
              item: item,
              onDetails: () => _details(item),
              onCompany: () => _companies.open(
                context,
                companyId: item.companyId,
                opportunityId: item.id,
                onRestricted: widget.onRestricted,
                onChanged: () => widget.onApplied?.call(),
                onViewApplications: widget.onViewApplications,
              ),
            ),
          ),
        ),
        if (_page?.hasNext == true && !_loading)
          OutlinedButton(
            onPressed: _failure == null ? () => _load() : null,
            child: const Text('Tải thêm cơ hội'),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.school_outlined, size: 19, color: AppColors.muted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TIP Career đồng hành cùng chặng đường nghề nghiệp của bạn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpportunityFilters extends StatefulWidget {
  const _OpportunityFilters({required this.type, required this.location});
  final String? type;
  final String location;
  @override
  State<_OpportunityFilters> createState() => _OpportunityFiltersState();
}

class _OpportunityFiltersState extends State<_OpportunityFilters> {
  late final _location = TextEditingController(text: widget.location);
  late String? _type = widget.type;
  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Lọc cơ hội',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bộ lọc áp dụng cho các cơ hội đã tải.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _types.entries
              .map(
                (entry) => ChoiceChip(
                  label: Text(entry.value),
                  selected: _type == entry.key,
                  onSelected: (_) => setState(() => _type = entry.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _location,
          key: const Key('opportunityLocationFilter'),
          decoration: const InputDecoration(
            labelText: 'Địa điểm',
            hintText: 'Ví dụ: Hà Nội',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            type: _type,
            location: _location.text.trim(),
          )),
          child: const Text('Áp dụng bộ lọc'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (type: null, location: '')),
          child: const Text('Xóa bộ lọc'),
        ),
      ],
    ),
  );
}
