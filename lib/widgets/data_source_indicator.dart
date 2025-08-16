// widgets/data_source_indicator.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/note_controller.dart';
import '../services/connectivity_service.dart';
import '../models/data_source.dart';

class DataSourceIndicator extends StatelessWidget {
  const DataSourceIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final noteController = Get.find<NoteController>();
    final connectivityController = Get.find<ConnectivityController>();

    return Obx(() {
      final dataSource = noteController.currentDataSource.value;
      final isConnected = connectivityController.isConnected;
      
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _getBackgroundColor(dataSource),
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getIcon(dataSource),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dataSource.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _getDetailedDescription(dataSource, isConnected),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (dataSource == DataSource.offline && isConnected)
              TextButton(
                onPressed: () => noteController.forceSyncOfflineToOnline(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text(
                  'Sync Now',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (dataSource == DataSource.syncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      );
    });
  }

  Color _getBackgroundColor(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.offline:
        return Colors.orange;
      case DataSource.online:
        return Colors.green;
      case DataSource.syncing:
        return Colors.blue;
    }
  }

  IconData _getIcon(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.offline:
        return Icons.cloud_off;
      case DataSource.online:
        return Icons.cloud_done;
      case DataSource.syncing:
        return Icons.sync;
    }
  }

  String _getDetailedDescription(DataSource dataSource, bool isConnected) {
    switch (dataSource) {
      case DataSource.offline:
        if (isConnected) {
          return 'Notes stored locally • Internet available • Tap "Sync Now" to sync';
        } else {
          return 'Notes stored locally • No internet connection';
        }
      case DataSource.online:
        return 'Notes synced with cloud • All changes saved online';
      case DataSource.syncing:
        return 'Synchronizing offline notes with online storage...';
    }
  }
}
