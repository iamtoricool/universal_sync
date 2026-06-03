String entityTypeName(Type type) {
  final raw = type.toString();
  final withoutGenerics = raw.contains('<') ? raw.substring(0, raw.indexOf('<')) : raw;
  final lastDot = withoutGenerics.lastIndexOf('.');
  final withoutPrefix = lastDot >= 0 ? withoutGenerics.substring(lastDot + 1) : withoutGenerics;
  final withoutParens = withoutPrefix.contains('(')
      ? withoutPrefix.substring(0, withoutPrefix.indexOf('('))
      : withoutPrefix;
  final name = withoutParens.trim();
  if (name.isEmpty) throw ArgumentError('type name must not be empty');
  return name;
}
