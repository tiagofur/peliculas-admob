import '../../repositories/user_profile_repository.dart';

class CheckUsernameAvailabilityUseCase {
  const CheckUsernameAvailabilityUseCase(this._repository);

  final UserProfileRepository _repository;

  Future<bool> execute(String username) {
    return _repository.checkUsernameAvailability(username);
  }
}
