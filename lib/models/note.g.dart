// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Note _$NoteFromJson(Map<String, dynamic> json) => Note(
  id: json['id'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  lastSyncedAt: json['last_synced_at'] == null
      ? null
      : DateTime.parse(json['last_synced_at'] as String),
  isDeleted: json['is_deleted'] == null
      ? false
      : Note._boolFromInt((json['is_deleted'] as num).toInt()),
  version: (json['version'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$NoteToJson(Note instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'content': instance.content,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'last_synced_at': instance.lastSyncedAt?.toIso8601String(),
  'is_deleted': Note._boolToInt(instance.isDeleted),
  'version': instance.version,
};
