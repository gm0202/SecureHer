import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/emergency_contact.dart';

class EmergencyContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    final userRef = _firestore.collection('users').doc(_userId);
    
    // Convert contacts to match the schema
    final contactsData = contacts.map((contact) => {
      'name': contact.name,
      'phone': contact.phoneNumber,
      'relationship': contact.relationship,
    }).toList();
    
    // Update user document with contacts and onboarding status
    await userRef.set({
      'onboarded': true,
      'emergency_contacts': contactsData,
      'lastUpdated': FieldValue.serverTimestamp(),
      'primary_contact': contacts.isNotEmpty ? contacts[0].phoneNumber : null,
    }, SetOptions(merge: true));
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final userDoc = await _firestore.collection('users').doc(_userId).get();
    
    if (!userDoc.exists) return [];
    
    final data = userDoc.data();
    if (data == null || !data.containsKey('emergency_contacts')) return [];
    
    final contactsData = data['emergency_contacts'] as List;
    return contactsData.map((contact) => EmergencyContact(
      name: contact['name'],
      phoneNumber: contact['phone'],
      relationship: contact['relationship'] ?? 'Emergency Contact',
    )).toList();
  }

  Future<bool> isOnboardingCompleted() async {
    final userDoc = await _firestore.collection('users').doc(_userId).get();
    return userDoc.exists && (userDoc.data()?['onboarded'] ?? false);
  }

  Future<String?> getPrimaryContactNumber() async {
    final userDoc = await _firestore.collection('users').doc(_userId).get();
    if (!userDoc.exists) return null;
    
    final data = userDoc.data();
    if (data == null) return null;
    
    // First try to get from primary_contact field
    if (data.containsKey('primary_contact')) {
      return data['primary_contact'] as String?;
    }
    
    // Fallback to first emergency contact
    if (data.containsKey('emergency_contacts') && (data['emergency_contacts'] as List).isNotEmpty) {
      return (data['emergency_contacts'] as List)[0]['phone'] as String?;
    }
    
    return null;
  }
} 