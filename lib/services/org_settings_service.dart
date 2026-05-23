import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

/// Persisted org configuration. All fields fall back to [AppConstants] defaults.
class OrgSettings {
  final String orgName;
  final String appName;
  final String tagline;
  final String missionPrefix;
  final String slogan;

  const OrgSettings({
    required this.orgName,
    required this.appName,
    required this.tagline,
    required this.missionPrefix,
    required this.slogan,
  });

  static OrgSettings get defaults => const OrgSettings(
        orgName:        AppConstants.orgName,
        appName:        AppConstants.appName,
        tagline:        AppConstants.appTagline,
        missionPrefix:  AppConstants.missionPrefix,
        slogan:         AppConstants.appSlogan,
      );

  OrgSettings copyWith({
    String? orgName,
    String? appName,
    String? tagline,
    String? missionPrefix,
    String? slogan,
  }) =>
      OrgSettings(
        orgName:       orgName       ?? this.orgName,
        appName:       appName       ?? this.appName,
        tagline:       tagline       ?? this.tagline,
        missionPrefix: missionPrefix ?? this.missionPrefix,
        slogan:        slogan        ?? this.slogan,
      );
}

/// Thin static wrapper around [SharedPreferences] for org settings.
class OrgSettingsService {
  static const _kOrgName    = 'org.name';
  static const _kAppName    = 'org.appName';
  static const _kTagline    = 'org.tagline';
  static const _kPrefix     = 'org.prefix';
  static const _kSlogan     = 'org.slogan';
  static const _kConfigured = 'org.configured';

  static Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConfigured) ?? false;
  }

  static Future<OrgSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final d = OrgSettings.defaults;
    return OrgSettings(
      orgName:       prefs.getString(_kOrgName)   ?? d.orgName,
      appName:       prefs.getString(_kAppName)   ?? d.appName,
      tagline:       prefs.getString(_kTagline)   ?? d.tagline,
      missionPrefix: prefs.getString(_kPrefix)    ?? d.missionPrefix,
      slogan:        prefs.getString(_kSlogan)    ?? d.slogan,
    );
  }

  static Future<void> save(OrgSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOrgName,    s.orgName);
    await prefs.setString(_kAppName,    s.appName);
    await prefs.setString(_kTagline,    s.tagline);
    await prefs.setString(_kPrefix,     s.missionPrefix);
    await prefs.setString(_kSlogan,     s.slogan);
    await prefs.setBool(_kConfigured,   true);
  }
}
