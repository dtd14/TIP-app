class PageSlice<T> {
  const PageSlice({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });
  final List<T> items;
  final int total, page, limit;
  bool get hasNext => page * limit < total;
}
