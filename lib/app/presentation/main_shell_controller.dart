/// Navigation intent shared by routes in the same authenticated account.
class MainShellController {
  final _listeners = <void Function()>{};
  bool _disposed = false;
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    if (_disposed) return;
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  void dispose() {
    _disposed = true;
    _listeners.clear();
  }

  int? requestedTab;
  int navigationRevision = 0, dashboardRevision = 0;
  void navigate(int tab) {
    requestedTab = tab;
    navigationRevision++;
    notifyListeners();
  }

  void refreshDashboard() {
    dashboardRevision++;
    notifyListeners();
  }
}
