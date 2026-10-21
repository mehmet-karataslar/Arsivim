import 'package:shared_preferences/shared_preferences.dart';
import 'auth_servisi.dart';

class AppLaunchState {
  const AppLaunchState({required this.showWelcome, required this.signedIn});
  final bool showWelcome, signedIn;
}

/// The welcome flag belongs to this installation, not to the signed-in session.
class AppLaunchService {
  AppLaunchService({
    Future<bool> Function()? restoreSession,
    Future<bool> Function()? hasExistingAccount,
  }) : _restoreSession = restoreSession ?? AuthServisi.instance.checkAutoLogin,
       _hasExistingAccount = hasExistingAccount ?? _existingAccount;
  static const welcomeSeenKey = 'app_welcome_seen';
  final Future<bool> Function() _restoreSession, _hasExistingAccount;

  static Future<bool> _existingAccount() async =>
      await (await AuthServisi.instance.hesapServisi).hesap() != null;

  Future<AppLaunchState> prepare() async {
    final prefs = await SharedPreferences.getInstance();
    final signedIn = await _restoreSession();
    final seen = prefs.getBool(welcomeSeenKey) ?? false;
    // An upgraded installation with an existing account is not a first use.
    final existing = !seen && (signedIn || await _hasExistingAccount());
    if (existing) await prefs.setBool(welcomeSeenKey, true);
    return AppLaunchState(showWelcome: !seen && !existing, signedIn: signedIn);
  }

  Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(welcomeSeenKey, true);
  }
}
