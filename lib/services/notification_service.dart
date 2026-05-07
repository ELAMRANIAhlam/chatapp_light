import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

class NotificationService {
  static Future<void> sendNotification(String deviceToken, String title, String body) async {
    if (deviceToken.isEmpty) return;

    try {
      final String response = await rootBundle.loadString('assets/service-account.json');
      final data = json.decode(response);

      final credentials = auth.ServiceAccountCredentials.fromJson(data);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final client = await auth.clientViaServiceAccount(credentials, scopes);
      final String projectId = data['project_id'];
      final String url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final Map<String, dynamic> message = {
        'message': {
          'token': deviceToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'priority': 'high', // Priorité maximale pour affichage immédiat
            'notification': {
              'sound': 'default',
              'channel_id': 'chat_messages', // IMPORTANT : doit être identique au main.dart
              'importance': 'high',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            }
          }
        }
      };
      
      await client.post(Uri.parse(url), body: jsonEncode(message));
      client.close();
      print("✅ Notification envoyée");
    } catch (e) {
      print("🚨 Erreur envoi : $e");
    }
  }
}