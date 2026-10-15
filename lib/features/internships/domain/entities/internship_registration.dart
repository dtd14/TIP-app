class InternshipRegistration {
  const InternshipRegistration({
    required this.id,
    required this.name,
    required this.status,
    required this.periodStatus,
    required this.startDate,
    required this.endDate,
    this.applyEndDate,
    this.applyStartDate,
    this.periodId,
    this.periodNumber,
    this.requiredHours,
    this.requiredWeeks,
  });
  final String id, name, status, periodStatus;
  final DateTime startDate, endDate;
  final DateTime? applyEndDate;
  final DateTime? applyStartDate;
  final String? periodId;
  final int? periodNumber, requiredHours, requiredWeeks;
  bool get isCompleted => status == 'COMPLETED';
  bool get isActive =>
      const {'OPEN', 'ONGOING'}.contains(periodStatus) &&
      const {'READY', 'APPLYING', 'PLACED', 'IN_PROGRESS'}.contains(status);
  String get periodStatusLabel => switch (periodStatus) {
    'DRAFT' => 'Bản nháp',
    'OPEN' => 'Đang mở',
    'ONGOING' => 'Đang diễn ra',
    'COMPLETED' => 'Đã kết thúc',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chưa xác định',
  };
  String titleAt(DateTime now) {
    if (periodStatus == 'COMPLETED' || now.isAfter(endDate)) {
      return 'Đợt thực tập gần nhất';
    }
    return now.isBefore(startDate)
        ? 'Đợt thực tập sắp tới'
        : 'Đợt thực tập hiện tại';
  }

  String get statusLabel => switch (status) {
    'READY' => 'Sẵn sàng',
    'APPLYING' => 'Đang nộp hồ sơ',
    'PLACED' => 'Đã có vị trí',
    'IN_PROGRESS' => 'Đang thực tập',
    'COMPLETED' => 'Đã hoàn thành',
    'FAILED' => 'Chưa hoàn thành',
    'NOT_ASSIGNED' => 'Chưa phân công',
    _ => 'Chưa xác định',
  };
}
