import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile _profile = const UserProfile(
    name: '',
    role: 'vo',
    email: '',
    unit: '',
    licenseNumber: '',
  );

  UserProfile get profile => _profile;

  Future<void> load() async {
    final saved = await DatabaseHelper.instance.getUserProfile();
    if (saved != null) {
      // Auto-demote expired PIC to 'tech' — license must be re-verified
      if (saved.role == 'pic' && saved.isLicenseExpired) {
        final demoted = saved.copyWith(role: 'tech');
        await DatabaseHelper.instance.saveUserProfile(demoted);
        _profile = demoted;
      } else {
        _profile = saved;
      }
      // Notify if license is expiring soon
      if (_profile.licenseVerified &&
          _profile.isLicenseExpiringSoon &&
          !_profile.isLicenseExpired) {
        final expiry = DateTime.parse(_profile.licenseExpiryDate!);
        final daysLeft = expiry.difference(DateTime.now()).inDays;
        await NotificationService.showLicenseExpiry(_profile.displayName, daysLeft);
      }
      notifyListeners();
    }
  }

  Future<void> update(UserProfile p) async {
    await DatabaseHelper.instance.saveUserProfile(p);
    _profile = p;
    notifyListeners();
  }
}
