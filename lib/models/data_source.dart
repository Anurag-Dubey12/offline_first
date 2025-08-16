// models/data_source.dart
enum DataSource {
  offline,
  online,
  syncing,
}

extension DataSourceExtension on DataSource {
  String get displayName {
    switch (this) {
      case DataSource.offline:
        return 'Offline Mode';
      case DataSource.online:
        return 'Online Mode';
      case DataSource.syncing:
        return 'Syncing...';
    }
  }

  String get description {
    switch (this) {
      case DataSource.offline:
        return 'Data stored locally only';
      case DataSource.online:
        return 'Data synced with cloud';
      case DataSource.syncing:
        return 'Synchronizing data...';
    }
  }
}
