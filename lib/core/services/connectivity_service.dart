import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

@riverpod
class ConnectivityService extends _$ConnectivityService {
  late Connectivity _connectivity;

  @override
  Stream<bool> build() {
    _connectivity = Connectivity();
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }

  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}

@riverpod
Stream<bool> isOnline(IsOnlineRef ref) {
  return ref.watch(connectivityServiceProvider);
}
