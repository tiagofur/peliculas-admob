import 'dart:typed_data';

import '../../repositories/user_profile_repository.dart';

class UploadAvatarUseCase {
  const UploadAvatarUseCase(this._repository);

  final UserProfileRepository _repository;

  Future<String> execute({
    required String userId,
    required Uint8List imageBytes,
    String? existingUrl,
    String? fileExtension,
  }) {
    return _repository.uploadAvatar(
      userId: userId,
      imageBytes: imageBytes,
      existingUrl: existingUrl,
      fileExtension: fileExtension,
    );
  }
}
