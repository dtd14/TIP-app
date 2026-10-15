class PlacementOverview {
  const PlacementOverview({
    required this.id,
    required this.title,
    required this.company,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.supervisor,
    this.companyId,
  });
  final String id, title, company, status;
  final DateTime startDate, endDate;
  final String? supervisor;
  final String? companyId;
  String get statusLabel => switch (status) {
    'PENDING' => 'Chờ xác nhận',
    'CONFIRMED' => 'Sắp bắt đầu',
    'IN_PROGRESS' => 'Đang thực tập',
    'COMPLETED' => 'Đã hoàn thành',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chưa xác định',
  };
}
