import '../../entities/user_profile.dart';
import '../../repositories/user_profile_repository.dart';

class GetUserProfileUseCase {
  const GetUserProfileUseCase(this._repository);

  final UserProfileRepository _repository;

  Future<UserProfile?> execute(String userId, {bool ensureExists = true}) {
    return _repository.fetchProfile(userId, ensureExists: ensureExists);
  }
}
