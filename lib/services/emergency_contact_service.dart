import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/emergency_contact.dart';

class EmergencyContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }
    return user.uid;
  }

  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    try {
      if (contacts.isEmpty) {
        throw Exception('At least one emergency contact is required');
      }

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
    } catch (e) {
      print('Error saving emergency contacts: $e');
      rethrow;
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
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
    } catch (e) {
      print('Error getting emergency contacts: $e');
      return [];
    }
  }

  Future<bool> isOnboardingCompleted() async {
    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      return userDoc.exists && (userDoc.data()?['onboarded'] ?? false);
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }

  Future<String?> getPrimaryContactNumber() async {
    try {
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
    } catch (e) {
      print('Error getting primary contact: $e');
      return null;
    }
  }

  Future<String?> getEmergencyContactPhone() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('emergency_contacts')
          .doc('primary')
          .get();

      if (doc.exists) {
        return doc.data()?['phone'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting emergency contact phone: $e');
      return null;
    }
  }

  String formatPhoneForWhatsApp(String phone) {
    // Remove any non-digit characters
    String digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // If the number starts with '0', replace with country code
    if (digitsOnly.startsWith('0')) {
      digitsOnly = '91' + digitsOnly.substring(1);
    }
    
    // If the number starts with country code, ensure it's in the correct format
    if (digitsOnly.startsWith('91')) {
      return digitsOnly; // Keep it as is, without '+' or spaces
    }
    
    // If the number doesn't have country code, add it
    return '91$digitsOnly';
  }

  String getWhatsAppUrl(String phone, String message) {
    final formattedPhone = formatPhoneForWhatsApp(phone);
    final encodedMessage = Uri.encodeComponent(message);
    // Use the direct WhatsApp URL format that bypasses the share sheet
    return 'https://wa.me/$formattedPhone?text=$encodedMessage';
  }
} 