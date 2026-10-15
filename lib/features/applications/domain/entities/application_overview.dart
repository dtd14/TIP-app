class ApplicationOverview {
  const ApplicationOverview({
    required this.id,
    required this.title,
    required this.company,
    required this.status,
    required this.appliedAt,
    this.updatedAt,
    this.opportunityId,
    this.type,
    this.companyVerified = false,
    this.companyId,
  });
  final String id, title, company, status;
  final DateTime appliedAt;
  final DateTime? updatedAt;
  final String? opportunityId, type, companyId;
  final bool companyVerified;
  bool get canWithdraw => status == 'PENDING' || status == 'REVIEWING';
  String get statusLabel => labelForStatus(status);
  static String labelForStatus(String status) => switch (status) {
    'PENDING' => 'Chờ duyệt',
    'REVIEWING' => 'Đang xem xét',
    'ACCEPTED' => 'Được nhận',
    'REJECTED' => 'Chưa phù hợp',
    'WITHDRAWN' => 'Đã rút',
    _ => 'Chưa xác định',
  };
}
