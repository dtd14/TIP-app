import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/features/profile/presentation/bloc/profile/profile_state.dart';
import 'package:tip_app/features/profile/presentation/bloc/profile/profile_event.dart';
import 'package:tip_app/features/profile/presentation/bloc/profile/profile_bloc.dart';
import 'package:tip_app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:tip_app/app/theme/app_colors.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/profile/domain/repositories/student_profile_repository.dart';
import 'package:tip_app/core/widgets/portal_ui.dart';
import 'package:tip_app/features/profile/presentation/widgets/profile_ui.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.repository,
    required this.onRestricted,
    required this.onLogout,
    required this.onChanged,
    required this.onEdit,
    required this.onManageCv,
    this.onEnrollment,
  });
  final AuthUser user;
  final StudentProfileRepository repository;
  final ValueChanged<AuthFailure> onRestricted;
  final VoidCallback onLogout, onChanged;
  final Future<bool> Function(StudentProfile) onEdit, onManageCv;
  final VoidCallback? onEnrollment;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  late final _bloc = ProfileBloc(widget.repository, widget.user);
  StudentProfile? get _profile => _bloc.state.profile;
  AuthFailure? get _failure => _bloc.state.failure;
  bool get _loading => _bloc.state.loading;
  Future<void> _load() => _bloc.dispatch(ProfileLoadRequested());
  void _onBlocState(BuildContext context, ProfileState state) {
    if (state.failure?.kind == FailureKind.inactiveAccount) {
      widget.onRestricted(state.failure!);
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<ProfileBloc, ProfileState>(
    bloc: _bloc,
    listener: _onBlocState,
    child: BlocBuilder<ProfileBloc, ProfileState>(
      bloc: _bloc,
      builder: (context, state) => _buildContent(context),
    ),
  );

  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _open(Future<bool> Function(StudentProfile) action) async {
    if (_opening || _loading || _profile == null || _failure != null) return;
    _opening = true;
    try {
      final changed = await action(_profile!);
      if (!mounted || !changed) return;
      await _load();
      if (mounted) widget.onChanged();
    } finally {
      _opening = false;
    }
  }

  Widget _buildContent(BuildContext context) {
    final profile = _profile;
    return DashboardScroll(
      onRefresh: _load,
      children: [
        const Text(
          'Hồ sơ sinh viên',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: LinearProgressIndicator(),
          ),
        if (_failure != null) ...[
          DashboardPanel(
            child: Column(
              children: [
                Text(_failure!.message, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (profile != null) ...[
          ProfileHero(
            profile: profile,
            onEdit: _loading || _failure != null
                ? null
                : () => _open(widget.onEdit),
          ),
          const SizedBox(height: 16),
          ProfileAcademicCard(profile: profile),
          const SizedBox(height: 16),
          ProfileCvCard(
            cvUrl: profile.cvUrl,
            onManage: () => _open(widget.onManageCv),
          ),
          const SizedBox(height: 16),
          DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeading(
                  'Thông tin tài khoản & liên hệ',
                  icon: Icons.contact_page_outlined,
                ),
                ProfileReadField(
                  'Họ và tên',
                  profile.fullName,
                  icon: Icons.person_outline_rounded,
                ),
                ProfileReadField(
                  'Email',
                  profile.email,
                  icon: Icons.mail_outline_rounded,
                ),
                if (widget.user.emailVerified) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: StatusPill('Email đã xác minh'),
                  ),
                ],
                ProfileReadField(
                  'Số điện thoại',
                  profile.phone ?? 'Chưa cập nhật',
                  icon: Icons.phone_outlined,
                ),
                if (widget.user.username != null)
                  ProfileReadField(
                    'Tên đăng nhập',
                    widget.user.username!,
                    icon: Icons.account_circle_outlined,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (widget.onEnrollment != null) ...[
            OutlinedButton.icon(
              onPressed: widget.onEnrollment,
              icon: const Icon(Icons.history_rounded, size: 17),
              label: const Text('Lịch sử ghi danh'),
            ),
            const SizedBox(height: 10),
          ],
        ],
        OutlinedButton.icon(
          key: const Key('profileLogout'),
          onPressed: widget.onLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB42318),
            backgroundColor: const Color(0xFFFFEBEB),
            minimumSize: const Size.fromHeight(48),
            side: BorderSide.none,
          ),
          icon: const Icon(Icons.logout_rounded, size: 17),
          label: const Text('Đăng xuất tài khoản'),
        ),
      ],
    );
  }
}
