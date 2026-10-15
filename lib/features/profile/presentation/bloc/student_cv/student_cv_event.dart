import 'dart:async';

sealed class StudentCvEvent {
  final Completer<void> completion = Completer<void>();
}

class StudentCvLoadRequested extends StudentCvEvent {
  StudentCvLoadRequested();
}

class StudentCvRecheckRequested extends StudentCvEvent {
  StudentCvRecheckRequested();
}

class StudentCvUploadRequested extends StudentCvEvent {
  StudentCvUploadRequested();
}
