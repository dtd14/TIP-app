import 'package:tip_app/features/profile/domain/entities/cv_upload.dart';
import 'package:file_selector/file_selector.dart';
import 'package:tip_app/core/errors/failures.dart';

Future<CvUpload?> pickStudentCv() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > CvUpload.maxBytes) {
    throw const AuthFailure(
      FailureKind.validation,
      'CV không được vượt quá 4 MiB.',
    );
  }
  return CvUpload(name: file.name, bytes: await file.readAsBytes());
}
