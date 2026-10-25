/// Form-field validators shared by every screen. Each returns `null` when the
/// value is valid, or a short user-facing message when it is not.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[\w.+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$');

  static String? required(String? v, {String field = 'This field'}) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  /// Required text with a trimmed length between [min] and [max].
  static String? text(String? v,
      {required String field, int min = 1, required int max}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$field is required';
    if (s.length < min) return '$field must be at least $min characters';
    if (s.length > max) return '$field must be $max characters or fewer';
    return null;
  }

  /// Optional text: only the upper length bound is checked.
  static String? optionalText(String? v, {required String field, required int max}) {
    final s = v?.trim() ?? '';
    return s.length > max ? '$field must be $max characters or fewer' : null;
  }

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (!_email.hasMatch(s)) return 'Enter a valid email, e.g. name@example.com';
    return null;
  }

  /// Sign-in only checks presence, so older accounts are never locked out.
  static String? passwordPresent(String? v) =>
      (v == null || v.isEmpty) ? 'Password is required' : null;

  /// Rules for a new password.
  static String? newPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 8) return 'Use at least 8 characters';
    if (s.length > 64) return 'Use 64 characters or fewer';
    if (s.contains(' ')) return 'Password cannot contain spaces';
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    return v == original ? null : 'Passwords do not match';
  }

  /// Whole number between [min] and [max] inclusive.
  static String? intInRange(String? v,
      {required String field, required int min, required int max}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$field is required';
    final n = int.tryParse(s);
    if (n == null) return 'Enter a whole number';
    if (n < min) return 'Minimum is $min';
    if (n > max) return 'Maximum is $max';
    return null;
  }

  /// Amount between [min] and [max] with at most two decimal places.
  static String? money(String? v,
      {required String field, double min = 0, required double max}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$field is required';
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) {
      return 'Enter an amount like 20 or 20.50';
    }
    final n = double.parse(s);
    if (n < min) return 'Minimum is ${min.toStringAsFixed(0)}';
    if (n > max) return 'Maximum is ${max.toStringAsFixed(0)}';
    return null;
  }

  static String? pickupCode(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter the pickup code';
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'The code is exactly 6 digits';
    return null;
  }
}
