// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 0;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      name: fields[1] as String,
      surname: fields[2] as String,
      email: fields[3] as String,
      role: fields[4] as String,
      tcid: fields[5] as String?,
      doctorId: fields[6] as String?,
      clinic: fields[7] as String?,
      expert: fields[8] as String?,
      experience: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.surname)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.role)
      ..writeByte(5)
      ..write(obj.tcid)
      ..writeByte(6)
      ..write(obj.doctorId)
      ..writeByte(7)
      ..write(obj.clinic)
      ..writeByte(8)
      ..write(obj.expert)
      ..writeByte(9)
      ..write(obj.experience);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
