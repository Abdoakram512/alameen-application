import 'package:equatable/equatable.dart';

class ContactInfoData extends Equatable {
  final String? email;
  final String? phone;
  final String? whatsapp;
  final String? address;

  const ContactInfoData({
    this.email,
    this.phone,
    this.whatsapp,
    this.address,
  });

  factory ContactInfoData.fromJson(Map<String, dynamic> json) {
    return ContactInfoData(
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      address: json['address']?.toString(),
    );
  }

  @override
  List<Object?> get props => [email, phone, whatsapp, address];
}
