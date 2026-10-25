import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String uid;
  final String name;
  final String role; // vendor | user | admin
  final String vendorType; // only meaningful for vendors

  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    required this.vendorType,
  });

  bool get isVendor => role == 'vendor';
  bool get isAdmin => role == 'admin';
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// Sign-up can only create `user` or `vendor` accounts.
  /// An admin is made by editing `role` to `admin` in the Firebase console.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String vendorType = 'canteen',
  }) async {
    final safeRole = role == 'vendor' ? 'vendor' : 'user';
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': safeRole,
      'vendorType': safeRole == 'vendor' ? vendorType : '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUser?> loadProfile(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    final d = snap.data()!;
    return AppUser(
      uid: uid,
      name: d['name'] ?? '',
      role: d['role'] ?? 'user',
      vendorType: d['vendorType'] ?? '',
    );
  }

  Future<void> signOut() => _auth.signOut();
}
