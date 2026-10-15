import 'dart:typed_data';
import 'package:tip_app/core/errors/failures.dart';

class CvUpload {
  factory CvUpload({required String name, required Uint8List bytes}) {
    if (bytes.length > maxBytes) {
      throw const AuthFailure(
        FailureKind.validation,
        'CV không được vượt quá 4 MiB (4.194.304 byte).',
      );
    }
    if (!name.toLowerCase().endsWith('.pdf') ||
        !String.fromCharCodes(bytes.take(1024)).contains('%PDF-')) {
      throw const AuthFailure(
        FailureKind.validation,
        'Vui lòng chọn tệp CV có nội dung PDF hợp lệ.',
      );
    }
    return CvUpload._(name, Uint8List.fromList(bytes));
  }
  const CvUpload._(this.name, this.bytes);
  static const maxBytes = 4194304;
  final String name;
  final Uint8List bytes;
  @override
  String toString() => 'CvUpload(redacted)';
}
