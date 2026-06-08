import 'package:flutter/material.dart';
import '../services/org_settings_service.dart';
import '../theme/app_theme.dart';

/// Provides org-level white-label settings throughout the widget tree.
/// Loaded once at startup; updated whenever [save] is called.
class OrgSettingsProvider extends ChangeNotifier {
  OrgSettings _settings = OrgSettings.defaults;
  bool _configured      = false;

  OrgSettings get settings       => _settings;
  bool        get isConfigured   => _configured;

  // Convenience pass-throughs so widgets can use
  // `context.watch<OrgSettingsProvider>().orgName` etc.
  String get orgName       => _settings.orgName;
  String get appName       => _settings.appName;
  String get tagline       => _settings.tagline;
  String get missionPrefix => _settings.missionPrefix;
  String get slogan        => _settings.slogan;
  String get logoPath      => _settings.logoPath;
  Color  get primaryColor  => AppColors.primary;

  Future<void> load() async {
    _configured = await OrgSettingsService.isConfigured();
    _settings   = await OrgSettingsService.load();
    notifyListeners();
  }

  Future<void> save(OrgSettings s) async {
    await OrgSettingsService.save(s);
    _settings   = s;
    _configured = true;
    notifyListeners();
  }
}
