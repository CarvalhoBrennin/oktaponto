final class XlsxSafeText {
  const XlsxSafeText._();

  static final _illegalXml = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');

  static String sanitize(String value) => value.replaceAll(_illegalXml, ' ');
}
