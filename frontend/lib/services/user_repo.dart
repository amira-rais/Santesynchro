// services/user_repo.dart
import 'package:firebase_auth/firebase_auth.dart';

class UserRepo {
  static final _auth = FirebaseAuth.instance;

  /// Crée/Met à jour le profil utilisateur actuel
  /// Note: Nécessite cloud_firestore pour la persistance Firestore
  static Future<void> upsertCurrentUserProfile() async {
    final u = _auth.currentUser;
    if (u == null) return;

    // TODO: Implémenter la persistance Firestore si nécessaire
    // Pour l'instant, les données sont gérées via Firebase Auth
  }
}