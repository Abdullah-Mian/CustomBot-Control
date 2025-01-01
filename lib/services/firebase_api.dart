import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseApi {
  // create a new instance of FirebaseMessaging
  final _firebaseMessaging = FirebaseMessaging.instance;
  //function to initialize notifications
  Future<void> initializeNotifications() async {
    //request permission to send notifications
    await _firebaseMessaging.requestPermission();
    //get the token
    final token = await _firebaseMessaging.getToken();
    // print('Token: $token');
  }
}
