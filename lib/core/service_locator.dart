import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/utils.dart';
import 'package:brecorder/data/all_storage_repository.dart';
import 'package:brecorder/data/icloud_repository.dart';
import 'package:brecorder/data/playlist_repository.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/presentation/pages/browser_view.dart';
import 'package:brecorder/presentation/ploc/home_page_state.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:brecorder/presentation/ploc/record_page_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/filesystem_repository.dart';
import '../data/trash_repository.dart';
import '../data/abstract_repository.dart';
import '../presentation/widgets/animated_sized_panel.dart';
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
    getIt.registerLazySingleton(() => AllStoreageBrowserViewState());
    getIt.registerLazySingleton(() => AudioServiceAgent());
    getIt.registerLazySingleton(() => FilesystemRepository());
    getIt.registerLazySingleton(() => ICloudRepository());
    getIt.registerLazySingleton(() => PlaylistRepository());
    getIt.registerLazySingleton(() => TrashRepository());
    getIt.registerLazySingleton(() => AllStorageRepository());
    getIt.registerLazySingleton(
        () => BrowserViewModeNotifier(BrowserViewMode.normal));
    getIt.registerLazySingleton(() => PriorityValueNotifier(
        AnimatedSizedPanelDragEvent(AnimatedSizedPanelDragEventType.init)));

    getIt.registerFactory(() => RecordPageState());

    // sl.registerLazySingleton(() => AudioPlayer());
    // sl.registerLazySingleton(() {
    //   final g = GlobalInfo();
    //   g.init();
    //   return g;
    // });
    asyncPref = SharedPreferences.getInstance();
    asyncPref.then((p) => pref = p);
  }
  late final SharedPreferences pref;
  late final Future<SharedPreferences> asyncPref;

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
      case RepoType.allStoreage:
        return getIt.get<AllStoreageBrowserViewState>();
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
      case RepoType.allStoreage:
        return getIt.get<AllStorageRepository>();
    }
  }

  PriorityValueNotifier<AnimatedSizedPanelDragEvent>
      get playbackPanelDragNotifier =>
          get<PriorityValueNotifier<AnimatedSizedPanelDragEvent>>();
}
