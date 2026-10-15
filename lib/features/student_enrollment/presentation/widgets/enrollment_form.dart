import 'package:tip_app/features/student_enrollment/presentation/bloc/enrollment_lookup/enrollment_lookup_state.dart';
import 'package:tip_app/features/student_enrollment/presentation/bloc/enrollment_lookup/enrollment_lookup_event.dart';
import 'package:tip_app/features/student_enrollment/presentation/bloc/enrollment_lookup/enrollment_lookup_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/widgets/app_text_field.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/student_enrollment/domain/entities/student_enrollment.dart';
import 'package:tip_app/features/student_enrollment/domain/enrollment_validation.dart';
import 'package:tip_app/features/student_enrollment/domain/repositories/student_enrollment_repository.dart';

class EnrollmentForm extends StatefulWidget {
  const EnrollmentForm({
    super.key,
    required this.repository,
    required this.onSubmit,
    required this.busy,
    required this.onRestricted,
  });
  final StudentEnrollmentRepository repository;
  final ValueChanged<StudentEnrollmentInput> onSubmit;
  final bool busy;
  final ValueChanged<AuthFailure> onRestricted;
  @override
  State<EnrollmentForm> createState() => _EnrollmentFormState();
}

class _EnrollmentFormState extends State<EnrollmentForm> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController(), _className = TextEditingController();
  EnrollmentSchool? _school;
  EnrollmentMajor? _major;
  late final _lookups = EnrollmentLookupBloc(widget.repository);
  List<EnrollmentMajor> get _majors => _lookups.state.majors;
  bool get _loadingMajors => _lookups.state.loadingMajors;
  AuthFailure? _validationFailure;
  AuthFailure? get _failure =>
      _lookups.state.majorFailure ?? _validationFailure;
  int _semester = 1;
  @override
  void dispose() {
    _lookups.close();
    _code.dispose();
    _className.dispose();
    super.dispose();
  }

  Future<void> _schoolPicker() async {
    final selected = await showModalBottomSheet<EnrollmentSchool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SchoolPicker(
        repository: widget.repository,
        onRestricted: widget.onRestricted,
      ),
    );
    if (!mounted || selected == null || widget.busy) return;
    setState(() {
      _school = selected;
      _major = null;
      _validationFailure = null;
    });
    await _loadMajors();
  }

  Future<void> _loadMajors() async {
    if (_school != null) _lookups.add(EnrollmentMajorsRequested(_school!.id));
  }

  void _submit() {
    if (widget.busy || _loadingMajors || !_form.currentState!.validate()) {
      return;
    }
    if (_school == null ||
        _major == null ||
        !_majors.any((major) => major.id == _major!.id)) {
      setState(
        () => _validationFailure = const AuthFailure(
          FailureKind.validation,
          'Vui lòng chọn trường và ngành học.',
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onSubmit(
      StudentEnrollmentInput(
        universityId: _school!.id,
        majorId: _major!.id,
        studentCode: _code.text.trim(),
        className: _className.text.trim(),
        semester: _semester,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<EnrollmentLookupBloc, EnrollmentLookupState>(
        bloc: _lookups,
        listener: (context, state) {
          if (state.majorFailure?.kind == FailureKind.inactiveAccount) {
            widget.onRestricted(state.majorFailure!);
          }
        },
        child: BlocBuilder<EnrollmentLookupBloc, EnrollmentLookupState>(
          bloc: _lookups,
          builder: (context, state) => _buildForm(context),
        ),
      );
  Widget _buildForm(BuildContext context) => DashboardPanel(
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            'Thông tin ghi danh',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 12),
          const Text(
            'Chọn trường đang theo học. Nhà trường sẽ xác minh thông tin trước khi cấp hồ sơ sinh viên.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('enrollmentSchool'),
            onPressed: widget.busy ? null : _schoolPicker,
            icon: const Icon(Icons.account_balance_outlined),
            label: Text(
              _school?.name ?? 'Chọn trường đại học',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 14),
          if (_loadingMajors) const LinearProgressIndicator(minHeight: 2),
          DropdownButtonFormField<String>(
            key: ValueKey('enrollmentMajor-${_school?.id}'),
            initialValue: _major?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ngành học',
              prefixIcon: Icon(Icons.menu_book_outlined),
            ),
            items: _majors
                .map(
                  (major) => DropdownMenuItem(
                    value: major.id,
                    child: Text(major.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: widget.busy || _loadingMajors
                ? null
                : (id) => setState(
                    () =>
                        _major = _majors.firstWhere((major) => major.id == id),
                  ),
            validator: (id) => id == null ? 'Vui lòng chọn ngành học.' : null,
          ),
          if (_school != null &&
              !_loadingMajors &&
              _failure == null &&
              _majors.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Trường chưa có ngành học khả dụng.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          if (_failure != null) ...[
            const SizedBox(height: 10),
            Text(
              _failure!.message,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
            ),
            if (_school != null)
              TextButton(
                onPressed: widget.busy || _loadingMajors ? null : _loadMajors,
                child: const Text('Tải lại ngành học'),
              ),
          ],
          const SizedBox(height: 18),
          AppTextField(
            key: const Key('enrollmentStudentCode'),
            label: 'Mã sinh viên',
            controller: _code,
            icon: Icons.badge_outlined,
            enabled: !widget.busy,
            validator: EnrollmentValidation.studentCode,
          ),
          AppTextField(
            key: const Key('enrollmentClass'),
            label: 'Lớp',
            controller: _className,
            icon: Icons.groups_outlined,
            enabled: !widget.busy,
            validator: EnrollmentValidation.className,
          ),
          DropdownButtonFormField<int>(
            key: const Key('enrollmentSemester'),
            initialValue: _semester,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Học kỳ',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: List.generate(
              8,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('Học kỳ ${index + 1}'),
              ),
            ),
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _semester = value!),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('enrollmentSubmit'),
            onPressed: widget.busy || _loadingMajors ? null : _submit,
            icon: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: const Text('Gửi yêu cầu ghi danh'),
          ),
        ],
      ),
    ),
  );
}

class _SchoolPicker extends StatefulWidget {
  const _SchoolPicker({required this.repository, required this.onRestricted});
  final StudentEnrollmentRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  @override
  State<_SchoolPicker> createState() => _SchoolPickerState();
}

class _SchoolPickerState extends State<_SchoolPicker> {
  final _search = TextEditingController();
  late final _lookups = EnrollmentLookupBloc(widget.repository);
  List<EnrollmentSchool> get _schools => _lookups.state.schools;
  bool get _loading => _lookups.state.loadingSchools;
  AuthFailure? get _failure => _lookups.state.schoolFailure;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lookups.close();
    _search.dispose();
    super.dispose();
  }

  void _changed(String keyword) =>
      _lookups.add(EnrollmentSchoolSearchChanged(keyword));
  void _load() => _lookups.add(EnrollmentSchoolsRequested(_search.text));
  @override
  Widget build(BuildContext context) =>
      BlocListener<EnrollmentLookupBloc, EnrollmentLookupState>(
        bloc: _lookups,
        listener: (context, state) {
          if (state.schoolFailure?.kind == FailureKind.inactiveAccount) {
            widget.onRestricted(state.schoolFailure!);
          }
        },
        child: BlocBuilder<EnrollmentLookupBloc, EnrollmentLookupState>(
          bloc: _lookups,
          builder: (context, state) => _buildPicker(context),
        ),
      );
  Widget _buildPicker(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        children: [
          const Text(
            'Chọn trường đại học',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Các trường đã được xác minh · tối đa 50 kết quả',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('enrollmentSchoolSearch'),
            controller: _search,
            onChanged: _changed,
            decoration: const InputDecoration(
              hintText: 'Tìm tên hoặc mã trường',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_failure != null) ...[
            Text(_failure!.message),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
          if (!_loading && _failure == null && _schools.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Chưa tìm thấy trường phù hợp.',
                textAlign: TextAlign.center,
              ),
            ),
          ..._schools.map(
            (school) => ListTile(
              key: Key('school-${school.id}'),
              leading: const DashboardIcon(Icons.account_balance_outlined),
              title: Text(school.name),
              subtitle: school.code == null ? null : Text(school.code!),
              onTap: () => Navigator.pop(context, school),
            ),
          ),
        ],
      ),
    ),
  );
}
