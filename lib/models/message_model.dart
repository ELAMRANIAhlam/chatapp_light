import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, audio }

class MessageModel {
  final String senderId;
  final String receiverId;
  final String message;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final bool isEdited;
  final bool isDeleted;
  final List<String> hiddenFor; // Liste des UIDs pour qui le message est caché

  MessageModel({
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false, /////
    this.isEdited = false,
    this.isDeleted = false,
    this.hiddenFor = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'type': type.index,
      'timestamp': timestamp,
      'isRead': isRead,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'hiddenFor': hiddenFor,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      type: MessageType.values[map['type'] ?? 0],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      isEdited: map['isEdited'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      hiddenFor: List<String>.from(map['hiddenFor'] ?? []),
    );
  }
}