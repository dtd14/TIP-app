import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/presentation/bloc/student_cv/student_cv_state.dart';
import 'package:tip_app/features/profile/presentation/bloc/student_cv/student_cv_event.dart';
import 'package:tip_app/features/profile/presentation/bloc/student_cv/student_cv_bloc.dart';
import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/profile/presentation/cv_file_picker.dart';
import 'package:tip_app/features/profile/presentation/widgets/profile_ui.dart';

class StudentCvPage extends StatefulWidget {
  const StudentCvPage({
    super.key,
    required this.user,
    required this.repository,
    required this.profileRepository,
    required this.onRestricted,
    this.pickCv = pickStudentCv,
  });
  final AuthUser user;
  final StudentProfileRepository repository;
  final StudentProfileRepository profileRepository;
  final ValueChanged<AuthFailure> onRestricted;
  final Future<CvUpload?> Function() pickCv;
  @override
  State<StudentCvPage> createState() => _StudentCvPageState();
}

class _StudentCvPageState extends State<StudentCvPage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = StudentCvBloc(
    widget.repository,
    widget.profileRepository,
    widget.user,
    widget.pickCv,
  );
  StudentProfile? get _profile => _bloc.state.profile;
  AuthFailure? get _failure => _bloc.state.failure;
  CvUpload? get _selected => _bloc.state.selected;
  bool get _loading => _bloc.state.loading;
  bool get _picking => _bloc.state.picking;
  bool get _uploading => _bloc.state.uploading;
  bool get _trusted => _bloc.state.trusted;
  bool get _changed => _bloc.state.changed;
  bool get _uncertain => _bloc.state.uncertain;
  Future<void> _load() => _bloc.dispatch(StudentCvLoadRequested());
  Future<void> _upload() async {
    await _bloc.dispatch(StudentCvUploadRequested());
    if (!mounted || !_bloc.state.uploadSucceeded) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật CV trong hồ sơ.')),
    );
  }

  void _onBlocState(BuildContext context, StudentCvState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<StudentCvBloc, StudentCvState>(
        bloc: _bloc,
        listener: _onBlocState,
        child: BlocBuilder<StudentCvBloc, StudentCvState>(
          bloc: _bloc,
          builder: (context, state) => _buildContent(context),
        ),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildContent(BuildContext context) {
    final busy = _loading || _picking || _uploading;
    final hasCv = _profile?.cvUrl != null;
    return PopScope<bool>(
      canPop: !(_picking || _uploading) && !_changed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_picking && !_uploading) {
          Navigator.pop(context, _changed);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'CV của tôi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            key: const Key('studentCvBack'),
            tooltip: 'Quay lại',
            onPressed: _picking || _uploading
                ? null
                : () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: DashboardScroll(
          onRefresh: _load,
          children: [
            const Text(
              'CV của tôi',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quản lý CV hiện tại dùng trong hồ sơ ứng tuyển của bạn.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 18),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: LinearProgressIndicator(),
              ),
            if (_failure != null) ...[
              DashboardPanel(
                child: Column(
                  children: [
                    Text(
                      _failure!.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                    if (_uncertain)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Kết quả tải lên chưa được xác nhận. Kiểm tra CV hiện tại trước khi tải lên lần nữa.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    TextButton(
                      key: const Key('reloadStudentCv'),
                      onPressed: busy ? null : _load,
                      child: const Text('Tải lại hồ sơ'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_profile != null)
              DashboardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(
                        !_trusted
                            ? 'Đang kiểm tra CV'
                            : hasCv
                            ? 'Có CV trong hồ sơ'
                            : 'Chưa có CV',
                        color: _trusted && hasCv
                            ? AppColors.accent
                            : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const DashboardIcon(
                          Icons.picture_as_pdf_outlined,
                          size: 48,
                          color: Color(0xFFB42318),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasCv
                                    ? 'CV hiện tại của bạn'
                                    : 'Bạn chưa có CV trong hồ sơ.',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _profile!.fullName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 52,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Mở tệp để xem nội dung CV',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Chỉ tải lên PDF, tối đa 4 MiB.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Tệp vừa chọn: ${_selected!.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ProfileCvActions(
                      viewKey: 'viewStudentCv',
                      cvUrl: _profile!.cvUrl,
                      enabled: _trusted && !busy,
                      action: FilledButton.icon(
                        key: const Key('uploadStudentCv'),
                        onPressed: !busy && _trusted && !_uncertain
                            ? _upload
                            : null,
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: Text(
                          _uploading
                              ? 'Đang tải lên…'
                              : _picking
                              ? 'Đang chọn tệp…'
                              : 'Tải lên CV mới',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            const DashboardPanel(
              child: Text(
                'CV mới sẽ thay thế CV hiện tại. Các đơn ứng tuyển đọc CV từ hồ sơ của bạn nên liên kết CV trong các đơn cũng sẽ thay đổi.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
