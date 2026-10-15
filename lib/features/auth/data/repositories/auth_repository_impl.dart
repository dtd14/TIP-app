import 'dart:async';
import 'package:dio/dio.dart';
import 'package:tip_app/core/errors/exceptions.dart';
import 'package:tip_app/core/errors/failures.dart';
import 'package:tip_app/core/storage/secure_storage.dart';
import 'package:tip_app/features/auth/domain/entities/auth_user.dart';
import 'package:tip_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:tip_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:tip_app/features/auth/data/models/auth_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.remote, required this.storage});
  final AuthRemoteDataSource remote;
  final SessionStorage storage;
  final _expired = StreamController<AuthFailure?>.broadcast();
  SessionCredential? _credential;
  AuthUser? _user;
  int _generation = 0;
  bool _signingOut = false;
  Future<void>? _storageQueue;
  Future<SessionCredential?>? _refreshWork;
  SessionCredential? _refreshSource;
  SessionCredential? _lastRefreshFrom;
  SessionCredential? _lastRefreshTo;
  SessionCredential? get credential => _credential;
  @override
  Stream<AuthFailure?> get sessionExpired => _expired.stream;

  Future<T> _withStorage<T>(Future<T> Function() action) {
    final queued = _storageQueue;
    final operation = queued == null ? action() : queued.then((_) => action());
    _storageQueue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  void _assertGeneration(int generation) {
    if (generation != _generation) {
      throw const AuthFailure(
        FailureKind.sessionExpired,
        'Phiên đã kết thúc. Vui lòng đăng nhập lại.',
      );
    }
  }

  Future<void> _save(AuthSessionModel session, int generation) =>
      _withStorage(() async {
        _assertGeneration(generation);
        if (!session.credential.isValid) {
          throw const AuthFailure(
            FailureKind.server,
            'Máy chủ chưa cấp phiên hợp lệ.',
          );
        }
        try {
          await storage.write(session.credential);
        } on Object {
          throw const AuthFailure(
            FailureKind.storage,
            'Không thể lưu phiên an toàn. Vui lòng thử lại.',
          );
        }
        if (generation != _generation) {
          await storage.clear();
          _assertGeneration(generation);
        }
        _credential = session.credential;
        _user = session.user;
        _lastRefreshFrom = null;
        _lastRefreshTo = null;
      });

  @override
  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async {
    final generation = ++_generation;
    try {
      final session = await remote.login(
        identifier: identifier,
        password: password,
      );
      await _save(session, generation);
      return _user!;
    } on Object catch (error) {
      throw _failure(error, initialLogin: true);
    }
  }

  @override
  Future<RegistrationOutcome> register(RegistrationInput input) async {
    final generation = _generation;
    try {
      final result = await remote.register(input);
      if (result.session != null) await _save(result.session!, generation);
      return RegistrationOutcome(
        message: result.message,
        user: result.session?.user,
        verificationEmail: result.verificationEmail,
        otpSent: result.otpSent,
      );
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final generation = _generation;
    try {
      if (_credential == null) {
        try {
          final saved = await storage.read();
          if (generation != _generation) return null;
          _credential = saved;
        } on AuthFailure {
          rethrow;
        } on Object {
          throw const AuthFailure(
            FailureKind.storage,
            'Không thể đọc phiên đã lưu. Vui lòng thử lại.',
          );
        }
      }
      if (_credential == null) return null;
      final user = await remote.currentUser();
      if (generation != _generation) return null;
      _user = user;
      return user;
    } on Object catch (error) {
      if (generation != _generation && _credential != null) return null;
      final failure = _failure(error, checkingSession: true);
      if (failure.kind == FailureKind.sessionExpired) await expireSession();
      throw failure;
    }
  }

  /// Single-flight rotation; stale requests from the previous access token share
  /// the winning rotation. Never refresh a different/new login or after sign-out.
  Future<SessionCredential?> refreshSession(SessionCredential failed) async {
    if (_signingOut) return null;
    if (identical(failed, _lastRefreshFrom) &&
        identical(_credential, _lastRefreshTo)) {
      return _credential;
    }
    if (!identical(failed, _credential) || failed.refreshToken == null) {
      return null;
    }
    if (_refreshWork != null && identical(failed, _refreshSource)) {
      return _refreshWork!;
    }
    final generation = _generation;
    final work = _rotate(failed, generation);
    _refreshWork = work;
    _refreshSource = failed;
    try {
      return await work;
    } finally {
      if (identical(_refreshWork, work)) {
        _refreshWork = null;
        _refreshSource = null;
      }
    }
  }

  Future<SessionCredential?> _rotate(
    SessionCredential failed,
    int generation,
  ) async {
    try {
      final rotated = await remote.refreshCredential(failed);
      if (!rotated.isValid || rotated.refreshToken == null) {
        throw const AuthFailure(
          FailureKind.server,
          'Máy chủ chưa cấp cặp token hợp lệ.',
        );
      }
      return await _withStorage(() async {
        if (generation != _generation ||
            !identical(failed, _credential) ||
            _signingOut) {
          return null;
        }
        try {
          await storage.write(rotated);
        } on Object {
          throw const AuthFailure(
            FailureKind.storage,
            'Không thể lưu phiên mới an toàn. Vui lòng thử lại.',
          );
        }
        if (generation != _generation || _signingOut) {
          await storage.clear();
          return null;
        }
        _credential = rotated;
        _lastRefreshFrom = failed;
        _lastRefreshTo = rotated;
        return rotated;
      });
    } on Object catch (error) {
      final failure = _failure(error, checkingSession: true);
      if (failure.kind == FailureKind.sessionExpired &&
          identical(failed, _credential)) {
        await expireSession();
      }
      throw failure;
    }
  }

  Future<void> expireSession() async {
    if (_credential == null) return;
    _generation++;
    _credential = null;
    _user = null;
    _lastRefreshFrom = null;
    _lastRefreshTo = null;
    try {
      await _withStorage(() => storage.clear());
    } on Object {
      const failure = AuthFailure(
        FailureKind.storage,
        'Không thể xóa phiên hết hạn. Vui lòng thử đăng xuất lại.',
      );
      _expired.add(failure);
      throw failure;
    }
    _expired.add(null);
  }

  @override
  Future<String?> logout() async {
    _generation++;
    _signingOut = true;
    _user = null;
    String? warning;
    try {
      if (_credential != null) {
        try {
          await remote.logout();
        } on Object {
          warning =
              'Đã đăng xuất trên thiết bị. Chưa xác nhận được việc kết thúc phiên trên máy chủ.';
        }
      }
      _generation++;
      _credential = null;
      _lastRefreshFrom = null;
      _lastRefreshTo = null;
      try {
        await _withStorage(() => storage.clear());
      } on Object {
        throw const AuthFailure(
          FailureKind.storage,
          'Không thể xóa phiên đã lưu. Vui lòng thử đăng xuất lại.',
        );
      }
      return warning;
    } finally {
      _signingOut = false;
    }
  }

  @override
  Future<void> verifyEmail({required String email, required String otp}) async {
    try {
      await remote.verifyEmail(email: email, otp: otp);
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<VerificationResendOutcome> resendVerificationEmail(
    String email,
  ) async {
    try {
      return await remote.resendVerificationEmail(email);
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  AuthFailure _failure(
    Object error, {
    bool initialLogin = false,
    bool checkingSession = false,
  }) {
    if (error is AuthFailure) return error;
    if (error is ApiException) return error.failure;
    if (error is DioException) {
      if (error.error is AuthFailure) return error.error as AuthFailure;
      if (error.error is ApiException) {
        return (error.error as ApiException).failure;
      }
      if ({
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(error.type)) {
        return const AuthFailure(
          FailureKind.timeout,
          'Kết nối quá thời gian chờ. Vui lòng thử lại.',
        );
      }
      if (error.type == DioExceptionType.connectionError) {
        return const AuthFailure(
          FailureKind.network,
          'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.',
        );
      }
      switch (error.response?.statusCode) {
        case 401:
          return AuthFailure(
            initialLogin
                ? FailureKind.invalidCredentials
                : checkingSession
                ? FailureKind.sessionExpired
                : FailureKind.forbidden,
            initialLogin
                ? 'Tên đăng nhập hoặc mật khẩu không đúng.'
                : checkingSession
                ? 'Phiên đã hết hạn. Vui lòng đăng nhập lại.'
                : 'Máy chủ chưa cho phép thực hiện thao tác này.',
          );
        case 403:
          return const AuthFailure(
            FailureKind.forbidden,
            'Tài khoản chưa được phép thực hiện thao tác này.',
          );
        case 400:
        case 409:
        case 422:
          return const AuthFailure(
            FailureKind.validation,
            'Thông tin chưa hợp lệ hoặc tài khoản đã tồn tại.',
          );
        case 429:
          return const AuthFailure(
            FailureKind.rateLimited,
            'Bạn đã gửi quá nhiều yêu cầu. Vui lòng chờ rồi thử lại.',
          );
        default:
          return const AuthFailure(
            FailureKind.server,
            'Máy chủ chưa xử lý được yêu cầu. Vui lòng thử lại.',
          );
      }
    }
    return const AuthFailure(
      FailureKind.unexpected,
      'Có lỗi xảy ra. Vui lòng thử lại.',
    );
  }

  Future<void> dispose() => _expired.close();
}
