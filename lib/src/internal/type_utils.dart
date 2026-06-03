String entityTypeName(Type type) {
  final raw = type.toString();
  final withoutGenerics = raw.contains('<') ? raw.substring(0, raw.indexOf('<')) : raw;
  final lastDot = withoutGenerics.lastIndexOf('.');
  final name = lastDot >= 0 ? withoutGenerics.substring(lastDot + 1) : withoutGenerics;
  if (name.isEmpty) throw ArgumentError('type name must not be empty');
  return name;
}
