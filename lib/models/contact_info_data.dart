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
      email: json['contactEmail']?.toString() ?? json['email']?.toString(),
      phone: json['contactPhone']?.toString() ?? json['phone']?.toString(),
      whatsapp: json['whatsappUrl']?.toString() ?? json['whatsapp']?.toString(),
      address: json['contactAddress']?.toString() ?? json['address']?.toString(),
    );
  }

  @override
  List<Object?> get props => [email, phone, whatsapp, address];
}
