
import 'package:firebase_analytics/firebase_analytics.dart';

abstract class AnalyticsService {
  Future<void> logSignUp({required String signUpMethod});
  Future<void> logLogin({required String loginMethod});
}

class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  Future<void> logSignUp({required String signUpMethod}) async {
    await _analytics.logSignUp(signUpMethod: signUpMethod);
  }

  @override
  Future<void> logLogin({required String loginMethod}) async {
    await _analytics.logLogin(loginMethod: loginMethod);
  }
}
