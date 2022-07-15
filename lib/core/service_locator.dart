import 'package:bb_recorder/core/audio_agent.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerLazySingleton(() => AudioServiceAgent());
}
