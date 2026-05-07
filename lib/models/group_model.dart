import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String groupId;
  final String groupName;
  final String groupIcon;
  final List<String> members; 
  final String lastMessage;
  final DateTime lastMessageTime;

  GroupModel({
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
    required this.members,
    required this.lastMessage,
    required this.lastMessageTime,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      groupIcon: map['groupIcon'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      // Sécurité : si lastMessageTime est nul dans Firestore, on met l'heure actuelle
      lastMessageTime: map['lastMessageTime'] != null 
          ? (map['lastMessageTime'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'groupIcon': groupIcon,
      'members': members,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
    };
  }
}