class AppConstants {
  // PocketBase Configuration
  static const String pocketbaseUrl = 'https://sijilli.pockethost.io';

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';

  // Database
  static const String dbName = 'sijilli.db';
  static const int dbVersion = 1;

  // Collections
  static const String usersCollection = 'users';
  static const String appointmentsCollection = 'appointments';
  static const String friendshipCollection = 'friendship';
  static const String postsCollection = 'posts';
  static const String invitationsCollection = 'invitations';
  static const String userAppointmentStatusCollection =
      'user_appointment_status';
  static const String visitsCollection = 'visits';
}
