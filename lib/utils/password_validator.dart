/// Validates password complexity.
///
/// Requirements:
/// - At least 8 characters
/// - At least one uppercase letter
/// - At least one lowercase letter
/// - At least one digit
/// - At least one special character
///
/// Returns null if valid, or an error message describing the first
/// unmet requirement.
String? validatePasswordComplexity(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'Password must be at least 8 characters';
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must contain at least one uppercase letter';
  }
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Password must contain at least one lowercase letter';
  }
  if (!RegExp(r'\d').hasMatch(value)) {
    return 'Password must contain at least one digit';
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
    return 'Password must contain at least one special character';
  }
  return null;
}
