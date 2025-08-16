// widgets/sync_status_widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SyncService>(
      builder: (syncService) {
        return GetBuilder<ConnectivityController>(
          builder: (connectivity) {
            return Column(
              children: [
                _buildConnectivityIndicator(connectivity),
                _buildSyncIndicator(syncService),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConnectivityIndicator(ConnectivityController connectivity) {
    return Obx(() {
      final info = connectivity.connectivityInfo.value;
      
      if (info.status == ConnectivityStatus.unknown) {
        return const SizedBox.shrink();
      }

      final color = info.isConnected ? Colors.green : Colors.red;
      final icon = info.isConnected ? Icons.wifi : Icons.wifi_off;
      final text = info.isConnected 
          ? 'Connected (${_getNetworkTypeText(info.networkType)})'
          : 'No Internet Connection';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSyncIndicator(SyncService syncService) {
    return Obx(() {
      final state = syncService.syncState.value;
      
      if (state.status == SyncStatus.idle) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getSyncStatusColor(state.status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getSyncStatusColor(state.status).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getSyncStatusIcon(state.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.message ?? _getSyncStatusText(state.status),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _getSyncStatusColor(state.status),
                    ),
                  ),
                ),
              ],
            ),
            if (state.status == SyncStatus.syncing && state.total > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.progressPercentage,
                backgroundColor: _getSyncStatusColor(state.status).withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getSyncStatusColor(state.status),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${state.progress} / ${state.total} items',
                style: TextStyle(
                  fontSize: 12,
                  color: _getSyncStatusColor(state.status),
                ),
              ),
            ],
            if (state.conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${state.conflicts.length} conflicts resolved',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Color _getSyncStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.conflict:
        return Colors.orange;
    }
  }

  Widget _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return const Icon(Icons.check_circle, size: 20, color: Colors.grey);
      case SyncStatus.syncing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.success:
        return const Icon(Icons.check_circle, size: 20, color: Colors.green);
      case SyncStatus.error:
        return const Icon(Icons.error, size: 20, color: Colors.red);
      case SyncStatus.conflict:
        return const Icon(Icons.warning, size: 20, color: Colors.orange);
    }
  }

  String _getSyncStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'All changes synchronized';
      case SyncStatus.syncing:
        return 'Synchronizing data...';
      case SyncStatus.success:
        return 'Sync completed successfully';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.conflict:
        return 'Sync completed with conflicts';
    }
  }

  String _getNetworkTypeText(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return 'WiFi';
      case NetworkType.mobile:
        return 'Mobile';
      case NetworkType.ethernet:
        return 'Ethernet';
      case NetworkType.none:
        return 'No Network';
    }
  }
}

// Floating Sync Button Widget
class SyncFloatingActionButton extends StatelessWidget {
  const SyncFloatingActionButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final syncService = Get.find<SyncService>();
    
    return Obx(() {
      final isSyncing = syncService.syncState.value.status == SyncStatus.syncing;
      final hasChanges = syncService.dataChanged.value;
      
      return FloatingActionButton(
        onPressed: isSyncing ? null : () async {
          await syncService.performSync();
        },
        backgroundColor: hasChanges 
            ? Colors.orange 
            : (isSyncing ? Colors.grey : Colors.blue),
        child: isSyncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                hasChanges ? Icons.sync_problem : Icons.sync,
                color: Colors.white,
              ),
      );
    });
  }
}