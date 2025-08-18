import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required String id,
    required String email,
    String? fullName,
    String? avatarUrl,
    required DateTime createdAt,
    DateTime? lastSignInAt,
    Map<String, dynamic>? userMetadata,
  }) : super(
    id: id,
    email: email,
    fullName: fullName,
    avatarUrl: avatarUrl,
    createdAt: createdAt,
    lastSignInAt: lastSignInAt,
    userMetadata: userMetadata,
  );

  factory UserModel.fromSupabaseUser(supabase.User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      createdAt: DateTime.parse(user.createdAt),
      lastSignInAt: user.lastSignInAt != null 
          ? DateTime.parse(user.lastSignInAt!) 
          : null,
      userMetadata: user.userMetadata,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.parse(json['last_sign_in_at'] as String)
          : null,
      userMetadata: json['user_metadata'] as Map<String, dynamic>?,
    );
  }






}