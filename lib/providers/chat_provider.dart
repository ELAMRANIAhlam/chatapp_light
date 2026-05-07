import 'package:chatapp_light/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverToken, // On récupère ça du profil du destinataire
    required String message,
  }) async {
    if (message.trim().isEmpty) return;

    // 1. Création de l'ID de la conversation (unique entre deux utilisateurs)
    List<String> ids = [senderId, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    // 2. Enregistrement du message dans Firestore
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'senderId': senderId,
          'receiverId': receiverId,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // 3. ENVOI DE LA NOTIFICATION (Le moment WhatsApp)
    if (receiverToken.isNotEmpty) {
      await NotificationService.sendNotification(
        receiverToken,
        senderName, // Le titre de la notif (ex: "Jean")
        message, // Le contenu (ex: "Salut !")
      );
    }
  }
}