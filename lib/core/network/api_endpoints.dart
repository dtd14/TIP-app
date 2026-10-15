/// Direct NestJS client routes. The deployed API has no global prefix.
abstract final class ApiEndpoints {
  static const login = '/auth/login';
  static const registerPersonalAccount = '/auth/register-user';
  static const registerSchoolUser = '/auth/register';
  static const currentUser = '/auth/me';
  static const logout = '/auth/logout';
  static const refreshToken = '/auth/refresh-token';
  static const verifyOtp = '/auth/verify-otp';
  static const resendOtp = '/auth/resend-otp';
  static const studentProfile = '/students/me';
  static const applications = '/applications';
  static const placements = '/placements';
  static const internshipPeriods = '/internship-period';
  static const publicOpportunities = '/public/opportunities';
  static const opportunities = '/opportunities';
  static const companies = '/companies';
  static const studentEnrollments = '/student-enrollments';
  static const notifications = '/notifications';
}
