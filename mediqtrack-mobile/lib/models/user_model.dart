// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String? name;
  final bool emailVerified;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.emailVerified = false,
  });

  // Convert Firebase User to UserModel
  factory UserModel.fromFirebaseUser(dynamic user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      emailVerified: user.emailVerified,
    );
  }

  // Convert UserModel to Map (optional, if want to save to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'emailVerified': emailVerified,
    };
  }
}
