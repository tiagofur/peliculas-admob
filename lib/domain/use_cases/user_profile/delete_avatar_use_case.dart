import '../../repositories/user_profile_repository.dart';

class DeleteAvatarUseCase {
  const DeleteAvatarUseCase(this._repository);

  final UserProfileRepository _repository;

  Future<void> execute(String userId) {
    return _repository.deleteAvatar(userId);
  }
}
