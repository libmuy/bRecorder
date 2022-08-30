import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/data/icloud_repository.dart';
import 'package:brecorder/data/playlist_repository.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/presentation/ploc/home_page_state.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:brecorder/presentation/ploc/record_page_state.dart';
import 'package:get_it/get_it.dart';

import '../data/filesystem_repository.dart';
import '../data/trash_repository.dart';
import '../domain/abstract_repository.dart';
import 'logging.dart';

final sl = ServiceLocator.instance;

final log = Logger("SL");

class ServiceLocator {
  final getIt = GetIt.instance;
  static final ServiceLocator _instance = ServiceLocator();
  static ServiceLocator get instance {
    return _instance;
  }

  ServiceLocator() {
    log.info("initialize services");
    getIt.registerLazySingleton(() => HomePageState());
    getIt.registerLazySingleton(() => FilesystemBrowserViewState());
    getIt.registerLazySingleton(() => ICloudBrowserViewState());
    getIt.registerLazySingleton(() => PlaylistBrowserViewState());
    getIt.registerLazySingleton(() => TrashBrowserViewState());
    getIt.registerLazySingleton(() => AudioServiceAgent());
    getIt.registerLazySingleton(() => FilesystemRepository());
    getIt.registerLazySingleton(() => ICloudRepository());
    getIt.registerLazySingleton(() => PlaylistRepository());
    getIt.registerLazySingleton(() => TrashRepository());

    getIt.registerFactory(() => RecordPageState());

    // sl.registerLazySingleton(() => AudioPlayer());
    // sl.registerLazySingleton(() {
    //   final g = GlobalInfo();
    //   g.init();
    //   return g;
    // });
  }

  T get<T extends Object>() {
    return getIt.get<T>();
  }

  BrowserViewState getBrowserViewState(RepoType type) {
    switch (type) {
      case RepoType.filesystem:
        return getIt.get<FilesystemBrowserViewState>();
      case RepoType.iCloud:
        return getIt.get<ICloudBrowserViewState>();
      case RepoType.playlist:
        return getIt.get<PlaylistBrowserViewState>();
      case RepoType.trash:
        return getIt.get<TrashBrowserViewState>();
    }
  }

  Repository getRepository(RepoType type) {
    switch (type) {
      case RepoType.filesystem:
        return getIt.get<FilesystemRepository>();
      case RepoType.iCloud:
        return getIt.get<ICloudRepository>();
      case RepoType.playlist:
        return getIt.get<PlaylistRepository>();
      case RepoType.trash:
        return getIt.get<TrashRepository>();
    }
  }
}
