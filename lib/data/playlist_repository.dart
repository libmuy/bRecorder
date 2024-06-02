// import '../core/result.dart';
// import '../domain/entities.dart';
import 'filesystem_repository.dart';
import 'repository.dart';

class PlaylistRepository extends FilesystemRepository {

  PlaylistRepository(super.rootPathFuture): super(type: RepoType.playlist) ;




}
