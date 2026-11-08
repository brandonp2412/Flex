Uri buildSupportEmail({required String subject, required String body}) => Uri(
  scheme: 'mailto',
  path: 'brandon@presley.nz',
  query:
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
);
