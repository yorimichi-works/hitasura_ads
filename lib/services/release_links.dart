/// Public, owner-approved URLs are injected by the release workflow.
/// There is deliberately no fallback to the retired web app's privacy policy.
abstract final class ReleaseLinks {
  static const privacyPolicy = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const support = String.fromEnvironment('SUPPORT_URL');

  static Uri? parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }
}
