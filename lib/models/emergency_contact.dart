class EmergencyContact {
  final String name;
  final String phoneNumber;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phoneNumber,
    required this.relationship,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'],
      phoneNumber: map['phoneNumber'],
      relationship: map['relationship'],
    );
  }
} 