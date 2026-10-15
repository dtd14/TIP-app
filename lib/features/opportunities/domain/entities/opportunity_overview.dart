class OpportunityOverview {
  const OpportunityOverview({
    required this.id,
    required this.title,
    required this.company,
    required this.type,
    required this.description,
    this.location,
    this.deadline,
    this.vacancies,
    this.status,
    this.companyId,
    this.companyLogoUrl,
    this.companyVerified = false,
  });
  final String id, title, company, type, description;
  final String? location;
  final DateTime? deadline;
  final int? vacancies;
  final String? status, companyId, companyLogoUrl;
  final bool companyVerified;
  String get statusLabel => switch (status) {
    'OPEN' => 'Đang mở',
    'CLOSED' => 'Đã đóng',
    'CANCELLED' => 'Đã hủy',
    'DRAFT' => 'Bản nháp',
    _ => 'Chưa xác định',
  };
  bool acceptsApplicationsAt(DateTime now) =>
      status == 'OPEN' && deadline != null && deadline!.isAfter(now);
  String get typeLabel => switch (type) {
    'INTERNSHIP' => 'Thực tập',
    'MICRO_INTERNSHIP' => 'Thực tập ngắn hạn',
    'JOB' => 'Việc làm',
    _ => 'Chưa xác định',
  };
}
