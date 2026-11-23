import 'package:equatable/equatable.dart';

enum UserRole {
  customer,
  restaurant,
  courier;

  static UserRole fromJson(String value) =>
      UserRole.values.firstWhere((role) => role.name == value);
}

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    role: UserRole.fromJson(json['role'] as String),
  );

  final int id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;

  @override
  List<Object?> get props => [id, name, email, phone, role];
}
