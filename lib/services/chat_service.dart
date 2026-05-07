import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join("_");
  }

  // Stream des messages optimisé
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore.collection('chats').doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Envoi de message
  Future<void> sendMessage(String chatId, MessageModel msg) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').add(msg.toMap());
    
    // Mise à jour pour le tri de la liste des discussions
    await _firestore.collection('users').doc(msg.senderId).update({'lastSeen': FieldValue.serverTimestamp()});
    await _firestore.collection('users').doc(msg.receiverId).update({'lastSeen': FieldValue.serverTimestamp()});
  }

  // Statut "écrit..."
  Future<void> setTypingStatus(String chatId, String userId, bool isTyping) async {
    await _firestore.collection('chats').doc(chatId).set({
      'typingStatus': { userId: isTyping }
    }, SetOptions(merge: true));
  }

  Future<void> markAsRead(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({'isRead': true});
  }
}