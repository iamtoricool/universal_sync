abstract class SyncEntity {
  const SyncEntity();

  String get id;
  int get version;
  DateTime get createdAt;
  DateTime get updatedAt;
  DateTime? get deletedAt;
  bool get isDeleted => deletedAt != null;
  bool get isNew => version == 0;
  Map<String, dynamic> toSyncJson();
}
