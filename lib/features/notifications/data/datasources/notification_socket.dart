abstract interface class NotificationSocket {
  Future<void> get ready;
  Stream<Object?> get messages;
  int? get closeCode;
  void send(String text);
  Future<void> close();
}

typedef NotificationSocketFactory =
    NotificationSocket Function(Uri uri, String? origin);
