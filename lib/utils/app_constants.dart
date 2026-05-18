/// White-label placeholder — swap these constants per deploying organization.
class AppConstants {
  AppConstants._();

  static const String appName = 'DUAS';
  static const String appTagline = 'UAS Fleet Management';
  static const String orgName = 'Davao UAS';
  static const String appSlogan = 'Safe  •  Responsible  •  Professional';
  static const String missionPrefix = 'UAS';
  static const String appVersion = '1.0.0';

  /// Progress-bar step labels shared by Equipment, Fit-to-Fly, and checklist screens.
  static const List<String> executionChecklistSteps = [
    'Equipment', 'Fit-to-Fly', 'Pre-flight', 'In-flight', 'Post-flight', 'Log',
  ];
}
