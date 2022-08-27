import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/data/icloud_repository.dart';
import 'package:brecorder/data/playlist_repository.dart';
import 'package:brecorder/presentation/ploc/home_page_state.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:brecorder/presentation/ploc/record_page_state.dart';
import 'package:get_it/get_it.dart';

import '../data/filesystem_repository.dart';
import '../data/trash_repository.dart';
import '../domain/entities_manager.dart';

final sl = GetIt.instance;

Future<void> init() async {
  sl.registerLazySingleton(() => HomePageState());
  sl.registerLazySingleton(() => FilesystemBrowserViewState());
  sl.registerLazySingleton(() => ICloudBrowserViewState());
  sl.registerLazySingleton(() => PlaylistBrowserViewState());
  sl.registerLazySingleton(() => TrashBrowserViewState());
  sl.registerLazySingleton(() => AudioServiceAgent());
  sl.registerLazySingleton(() => FilesystemRepository());
  sl.registerLazySingleton(() => ICloudRepository());
  sl.registerLazySingleton(() => PlaylistRepository());
  sl.registerLazySingleton(() => TrashRepository());
  sl.registerLazySingleton(() => const EntitiesManager());

  sl.registerFactory(() => RecordPageState());

  // sl.registerLazySingleton(() => AudioPlayer());
  // sl.registerLazySingleton(() {
  //   final g = GlobalInfo();
  //   g.init();
  //   return g;
  // });
}
