import 'package:equatable/equatable.dart';

enum UserRole {
  customer,
  restaurant,
  courier,
  admin;

  static UserRole fromJson(String value) =>
      UserRole.values.firstWhere((role) => role.name == value);
}

/// Whether an admin has reviewed the account. Restaurants and couriers start
/// as [pending] and cannot work until [approved].
enum AccountStatus {
  pending,
  approved,
  suspended;

  static AccountStatus fromJson(String value) =>
      AccountStatus.values.firstWhere((status) => status.name == value);
}

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status = AccountStatus.approved,
    this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    role: UserRole.fromJson(json['role'] as String),
    status: AccountStatus.fromJson(json['status'] as String? ?? 'approved'),
  );

  final int id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final AccountStatus status;

  bool get isPending => status == AccountStatus.pending;

  @override
  List<Object?> get props => [id, name, email, phone, role, status];
}
