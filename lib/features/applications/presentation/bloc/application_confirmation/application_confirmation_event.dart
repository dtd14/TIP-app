import 'dart:async';

sealed class ApplicationConfirmationEvent {
  final Completer<void> completion = Completer<void>();
}

class ApplicationPreparationRequested extends ApplicationConfirmationEvent {
  ApplicationPreparationRequested();
}

class ApplicationSubmissionRequested extends ApplicationConfirmationEvent {
  ApplicationSubmissionRequested();
}

class ApplicationConsentChanged extends ApplicationConfirmationEvent {
  ApplicationConsentChanged(this.value);
  final bool value;
}
