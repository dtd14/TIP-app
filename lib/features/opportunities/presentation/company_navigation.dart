import 'package:tip_app/features/internships/domain/usecases/get_placement.dart';
import 'package:tip_app/features/applications/domain/usecases/get_application.dart';
import 'package:tip_app/features/opportunities/domain/usecases/get_opportunity.dart';
import 'package:tip_app/features/internships/domain/repositories/internship_repository.dart';
import 'package:tip_app/features/applications/domain/repositories/application_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:tip_app/features/opportunities/domain/repositories/opportunity_repository.dart';
import 'package:tip_app/features/opportunities/presentation/pages/company_detail_page.dart';

/// Resolves missing identifiers through owned/authenticated records, never names.
class CompanyNavigation {
  bool _opening = false;
  bool get isOpening => _opening;
  Future<void> open(
    BuildContext context, {
    required ValueChanged<AuthFailure> onRestricted,
    required VoidCallback onChanged,
    VoidCallback? onViewApplications,
    String? companyId,
    String? opportunityId,
    String? applicationId,
    String? placementId,
  }) async {
    if (_opening) return;
    final user = context.read<AuthBloc>().state.user;
    if (user == null || !user.canAccessHome) return;
    _opening = true;
    try {
      var id = companyId;
      if (id == null && user.canAccessStudentApp) {
        if (opportunityId != null) {
          id = (await GetOpportunity(context.read<OpportunityRepository>())(
            opportunityId,
          )).companyId;
        } else if (applicationId != null) {
          id = (await GetApplication(context.read<ApplicationRepository>())(
            applicationId,
            user,
          )).application.companyId;
        } else if (placementId != null) {
          id = (await GetPlacement(context.read<InternshipRepository>())(
            placementId,
            user,
          )).companyId;
        }
      }
      if (!context.mounted) return;
      if (id == null || id.isEmpty) {
        throw const AuthFailure(
          FailureKind.integrationUnavailable,
          'Chưa thể mở thông tin doanh nghiệp từ mục này.',
        );
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CompanyDetailPage(
            companyId: id!,
            user: user,
            repository: context.read<OpportunityRepository>(),
            onRestricted: onRestricted,
            onChanged: onChanged,
            onViewApplications: onViewApplications,
          ),
        ),
      );
    } on AuthFailure catch (failure) {
      if (!context.mounted) return;
      if (failure.kind == FailureKind.inactiveAccount) {
        onRestricted(failure);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa thể mở thông tin doanh nghiệp. Vui lòng thử lại.',
            ),
          ),
        );
      }
    } finally {
      _opening = false;
    }
  }
}
