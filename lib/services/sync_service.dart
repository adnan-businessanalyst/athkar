import 'api_client.dart';
import 'local_repository.dart';

class SyncService {
  SyncService(this.api, this.repo);

  final ApiClient api;
  final LocalRepository repo;

  Future<void> pull() async {
    final since = await repo.serverRevision();
    final data = await api.get(
      '/sync',
      query: {'since': '$since'},
    );
    await repo.applySyncResponse(data);
  }

  Future<void> push({required bool includeAll}) async {
    if (!includeAll && !await repo.hasDirty()) {
      await pull();
      return;
    }
    final body = await repo.buildPushBody(includeAll: includeAll);
    final data = await api.post('/sync', body, auth: true);
    await repo.applySyncResponse(data);
  }
}
