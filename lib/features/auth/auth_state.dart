// Login/session state for the app. Deliberately simple: no persisted
// session across restarts (every launch requires a fresh login), no
// password-reset flow — this is a single-office desktop tool, not a
// multi-tenant SaaS product. See /CLAUDE.md's auth note for the context
// this resolves (each staff PC has its own local database; the client
// asked for real staff accounts so an admin can control who sees/edits
// what and who's allowed to add other staff).
//
// Passwords are bcrypt-hashed with package:bcrypt, the same scheme the
// legacy PHP app already used for Staff.passwordHash — so accounts
// carried over via the CSV importer log in exactly like freshly-created
// ones (see csv_legacy_importer.dart).

import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';

const _uuid = Uuid();

enum AuthStatus { checking, needsSetup, loggedOut, loggedIn }

class AuthState extends ChangeNotifier {
  final AppDatabase db;
  AuthState(this.db) {
    _init();
  }

  AuthStatus status = AuthStatus.checking;
  StaffData? currentUser;
  String? lastError;

  bool get isAdmin => currentUser?.role == 'admin';

  Future<void> _init() async {
    final hasStaff = await db.staffDao.hasAnyStaff();
    status = hasStaff ? AuthStatus.loggedOut : AuthStatus.needsSetup;
    notifyListeners();
  }

  /// Creates the very first account, always as admin — there is no staff
  /// to log in as yet, so this is the only account creation path that
  /// doesn't require an existing admin to be logged in.
  Future<bool> createInitialAdmin({
    required String fullName,
    required String username,
    required String password,
  }) async {
    if (status != AuthStatus.needsSetup) return false;
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    final id = _uuid.v4();
    await db.staffDao.upsert(StaffCompanion.insert(
      id: id,
      username: username,
      fullName: fullName,
      role: const Value('admin'),
      passwordHash: Value(hash),
    ));
    currentUser = StaffData(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
      username: username,
      fullName: fullName,
      role: 'admin',
      passwordHash: hash,
    );
    status = AuthStatus.loggedIn;
    notifyListeners();
    return true;
  }

  Future<bool> login(String username, String password) async {
    final staffMember = await db.staffDao.byUsername(username.trim());
    if (staffMember == null || staffMember.passwordHash == null) {
      lastError = 'Unknown username or password.';
      notifyListeners();
      return false;
    }
    final ok = BCrypt.checkpw(password, staffMember.passwordHash!);
    if (!ok) {
      lastError = 'Unknown username or password.';
      notifyListeners();
      return false;
    }
    lastError = null;
    currentUser = staffMember;
    status = AuthStatus.loggedIn;
    notifyListeners();
    return true;
  }

  void logout() {
    currentUser = null;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }
}
