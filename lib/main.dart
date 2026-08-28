import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/cloud_progress_service.dart';
import 'services/google_auth_service.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb && Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (error) {
      debugPrint('Firebase initialization failed: ${error.code} $error');
    }
  }
  final googleAuth = GoogleAuthService();
  await googleAuth.initialize();
  final cloudStore = kIsWeb && Firebase.apps.isNotEmpty
      ? FirestoreProgressCloudStore()
      : null;
  final controller = await AppController.create(
    authSession: googleAuth,
    cloudStore: cloudStore,
  );
  runApp(HitasuraAdsApp(controller: controller));
}
