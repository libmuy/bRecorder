import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/home/data/filesystem_repository.dart';
import 'package:brecorder/home/data/icloud_repository.dart';
import 'package:brecorder/home/data/playlist_repository.dart';
import 'package:brecorder/home/domain/entities_manager.dart';
import 'package:brecorder/home/presentation/ploc/home_page_state.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerFactory(() => HomePageState());
  sl.registerLazySingleton(() => AudioServiceAgent());
  sl.registerLazySingleton(() => FilesystemRepository());
  sl.registerLazySingleton(() => ICloudRepository());
  sl.registerLazySingleton(() => PlaylistRepository());
  sl.registerLazySingleton(() => const EntitiesManager());
  // sl.registerLazySingleton(() {
  //   final g = GlobalInfo();
  //   g.init();
  //   return g;
  // });
}
