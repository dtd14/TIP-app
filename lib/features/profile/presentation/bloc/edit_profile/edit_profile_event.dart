import 'dart:async';

sealed class EditProfileEvent {
  final Completer<void> completion = Completer<void>();
}

class EditProfileCvPickRequested extends EditProfileEvent {
  EditProfileCvPickRequested();
}

class EditProfileRecheckRequested extends EditProfileEvent {
  EditProfileRecheckRequested();
}

class EditProfileSaveRequested extends EditProfileEvent {
  EditProfileSaveRequested(this.fullName, this.phone);
  final String fullName;
  final String phone;
}

class EditProfileCvRemoved extends EditProfileEvent {
  EditProfileCvRemoved();
}
