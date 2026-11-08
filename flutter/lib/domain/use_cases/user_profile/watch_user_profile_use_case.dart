import '../../entities/user_profile.dart';
import '../../repositories/user_profile_repository.dart';

class WatchUserProfileUseCase {
  const WatchUserProfileUseCase(this._repository);

  final UserProfileRepository _repository;

  Stream<UserProfile?> execute(String userId) {
    return _repository.watchProfile(userId);
  }
}
