class RegistrationRequestModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String approvalStatus;
  final String? rejectionReason;
  final DateTime? createdAt;
  final String? tenantId;
  final double? monthlyRent;
  final double? securityDeposit;
  final String? assignedRoomNumber;
  final String? assignedRoomId;

  const RegistrationRequestModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.approvalStatus,
    this.rejectionReason,
    this.createdAt,
    this.tenantId,
    this.monthlyRent,
    this.securityDeposit,
    this.assignedRoomNumber,
    this.assignedRoomId,
  });

  factory RegistrationRequestModel.fromJson(Map<String, dynamic> json) {
    final tenantObj = json['tenant'] is Map<String, dynamic> ? json['tenant'] as Map<String, dynamic> : null;
    final roomObj = tenantObj != null && tenantObj['room'] is Map<String, dynamic>
        ? tenantObj['room'] as Map<String, dynamic>
        : null;

    return RegistrationRequestModel(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'tenant',
      approvalStatus: json['approvalStatus']?.toString() ?? 'pending',
      rejectionReason: json['rejectionReason']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      tenantId: tenantObj != null ? tenantObj['_id']?.toString() : null,
      monthlyRent: tenantObj != null && tenantObj['monthlyRent'] != null
          ? (tenantObj['monthlyRent'] as num).toDouble()
          : null,
      securityDeposit: tenantObj != null && tenantObj['securityDeposit'] != null
          ? (tenantObj['securityDeposit'] as num).toDouble()
          : null,
      assignedRoomNumber: roomObj != null ? roomObj['roomNumber']?.toString() : null,
      assignedRoomId: roomObj != null ? roomObj['_id']?.toString() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'approvalStatus': approvalStatus,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
