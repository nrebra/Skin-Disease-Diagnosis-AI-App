import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String surname;

  @HiveField(3)
  final String email;

  @HiveField(4)
  final String role;

  @HiveField(5)
  final String? tcid;

  @HiveField(6)
  final String? doctorId;

  @HiveField(7)
  final String? clinic;

  @HiveField(8)
  final String? expert;

  @HiveField(9)
  final String? experience;

  UserModel({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.role,
    this.tcid,
    this.doctorId,
    this.clinic,
    this.expert,
    this.experience,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      name: json['name'],
      surname: json['surname'],
      email: json['email'],
      role: json['role'],
      tcid: json['tcid'],
      doctorId: json['doctor_id']?.toString(),
      clinic: json['clinic'],
      expert: json['expert'],
      experience: json['experience'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'email': email,
      'role': role,
      'tcid': tcid,
      'doctor_id': doctorId,
      'clinic': clinic,
      'expert': expert,
      'experience': experience,
    };
  }
}
