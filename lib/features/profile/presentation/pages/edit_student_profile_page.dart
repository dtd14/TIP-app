import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/presentation/bloc/edit_profile/edit_profile_state.dart';
import 'package:tip_app/features/profile/presentation/bloc/edit_profile/edit_profile_event.dart';
import 'package:tip_app/features/profile/presentation/bloc/edit_profile/edit_profile_bloc.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/utils/validators.dart';
import 'package:tip_app/core/widgets/app_text_field.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/features/profile/presentation/cv_file_picker.dart';
import 'package:tip_app/features/profile/presentation/widgets/profile_ui.dart';

class EditStudentProfilePage extends StatefulWidget {
  const EditStudentProfilePage({
    super.key,
    required this.profile,
    required this.repository,
    required this.onRestricted,
    this.reloadProfile,
    this.pickCv = pickStudentCv,
  });
  final StudentProfile profile;
  final StudentProfileRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final Future<StudentProfile> Function()? reloadProfile;
  final Future<CvUpload?> Function() pickCv;
  @override
  State<EditStudentProfilePage> createState() => _EditStudentProfilePageState();
}

class _EditStudentProfilePageState extends State<EditStudentProfilePage> {
  late final _bloc = EditProfileBloc(
    widget.repository,
    widget.profile,
    widget.reloadProfile,
    widget.pickCv,
  );
  StudentProfile get _profile => _bloc.state.profile;
  CvUpload? get _cv => _bloc.state.cv;
  AuthFailure? get _failure => _bloc.state.failure;
  bool get _saving => _bloc.state.saving;
  bool get _picking => _bloc.state.picking;
  bool get _checking => _bloc.state.checking;
  bool get _uncertain => _bloc.state.uncertain;
  bool get _mayHaveChanged => _bloc.state.mayHaveChanged;
  Future<void> _pickCv() => _bloc.dispatch(EditProfileCvPickRequested());
  Future<void> _recheck() => _bloc.dispatch(EditProfileRecheckRequested());
  Future<void> _save() async {
    if (_busy || _uncertain || !_changed || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    await _saveProfile(_name.text, _phone.text);
  }

  Future<void> _check() async {
    await _recheck();
    if (!mounted || _failure != null) return;
    _name.text = _profile.fullName;
    _phone.text = _profile.phone ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã tải hồ sơ hiện tại. Kiểm tra thông tin trước khi lưu lại.',
        ),
      ),
    );
  }

  Future<void> _saveProfile(String fullName, String phone) =>
      _bloc.dispatch(EditProfileSaveRequested(fullName, phone));
  Future<void> _removeCv() => _bloc.dispatch(EditProfileCvRemoved());
  void _onBlocState(BuildContext context, EditProfileState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
    if (state.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật hồ sơ sinh viên.')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<EditProfileBloc, EditProfileState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure ||
            previous.saved != current.saved,
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<EditProfileBloc, EditProfileState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  bool get _busy => _saving || _picking || _checking;
  bool get _changed =>
      _name.text.trim() != _profile.fullName ||
      _phone.text.trim() != (_profile.phone ?? '') ||
      _cv != null;
  @override
  void initState() {
    super.initState();
    _name.addListener(_edited);
    _phone.addListener(_edited);
  }

  void _edited() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bloc.close();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Widget _buildContent(BuildContext context) => PopScope<bool>(
    canPop: !_busy && !_mayHaveChanged,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy) Navigator.pop(context, _mayHaveChanged);
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          key: const Key('profileEditBack'),
          tooltip: 'Quay lại',
          onPressed: _busy
              ? null
              : () => Navigator.pop(context, _mayHaveChanged),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileHero(profile: _profile),
                  const SizedBox(height: 16),
                  DashboardPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(
                          'Thông tin cá nhân & liên hệ',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: StatusPill('Có thể chỉnh sửa'),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          key: const Key('profileEditName'),
                          label: 'Họ và tên *',
                          controller: _name,
                          icon: Icons.person_outline_rounded,
                          enabled: !_busy && !_uncertain,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vui lòng nhập họ và tên.'
                              : null,
                        ),
                        AppTextField(
                          key: const Key('profileEditPhone'),
                          label: 'Số điện thoại',
                          controller: _phone,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          enabled: !_busy && !_uncertain,
                          validator: Validators.phone,
                        ),
                        ProfileReadField(
                          'Email · Chỉ đọc',
                          _profile.email,
                          icon: Icons.mail_outline_rounded,
                          trailing: const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProfileAcademicCard(profile: _profile, explain: true),
                  const SizedBox(height: 16),
                  DashboardPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(
                          'CV của bạn',
                          icon: Icons.description_outlined,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chỉ tệp PDF, tối đa 4 MiB. CV mới thay thế CV trong hồ sơ và các đơn ứng tuyển.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.muted,
                          ),
                        ),
                        if (_cv != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _cv!.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: _busy || _uncertain
                                ? null
                                : () => _removeCv(),
                            child: const Text('Bỏ tệp vừa chọn'),
                          ),
                        ] else if (_profile.cvUrl != null) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Bạn đã có CV. Chọn tệp mới để thay thế.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('profilePickCv'),
                          onPressed: _busy || _uncertain ? null : _pickCv,
                          icon: const Icon(
                            Icons.upload_file_outlined,
                            size: 17,
                          ),
                          label: Text(
                            _picking ? 'Đang đọc tệp…' : 'Chọn CV PDF',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_failure != null) ...[
                    const SizedBox(height: 16),
                    DashboardPanel(
                      child: Column(
                        children: [
                          Text(
                            _failure!.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          if (_uncertain && widget.reloadProfile != null)
                            TextButton(
                              key: const Key('profileRecheck'),
                              onPressed: _busy ? null : _check,
                              child: const Text('Kiểm tra lại hồ sơ'),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const Key('profileSave'),
                    onPressed: _busy || _uncertain || !_changed ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 17),
                    label: Text(_saving ? 'Đang lưu…' : 'Lưu thay đổi'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('profileEditCancel'),
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, _mayHaveChanged),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Hủy bỏ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
