/*import 'package:cloud_firestore/cloud_firestore.dart';

/// Cette classe représente l'utilisateur au sein de l'application.
/// Elle correspond à la collection "users" mentionnée dans le cahier des charges[cite: 34].
class UserModel {
  // Identifiant unique généré par Firebase Auth [cite: 27]
  final String uid;
  
  // Informations de profil de l'utilisateur [cite: 33]
  final String name;
  final String email;
  final String photoUrl; // URL de l'image stockée dans Firebase Storage [cite: 15]
  
  // Gestion de la présence en temps réel [cite: 9, 39]
  final bool isOnline; // Statut : en ligne (true) ou hors ligne (false) [cite: 62]
  final DateTime lastSeen; // Horodatage de la dernière activité
  
  // Token pour les notifications push (fonctionnalité bonus) 
  final String fcmToken;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isOnline,
    required this.lastSeen,
    this.fcmToken = "",
  });

  /// Convertit l'objet UserModel en Map (JSON) pour l'envoyer à Cloud Firestore.
  /// Firestore nécessite ce format pour stocker les données[cite: 14].
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      // Conversion de la date en millisecondes pour une sauvegarde standardisée
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'fcmToken': fcmToken,
    };
  }

  /// Crée une instance de UserModel à partir des données reçues de Firestore.
  /// C'est ici que l'on transforme les données brutes en objet manipulable par Flutter.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    
    /// Fonction interne de sécurité pour gérer les dates.
    /// Firestore renvoie parfois un 'Timestamp' et parfois un 'int' (millisecondes).
    /// Cette logique évite les plantages lors de la synchronisation en temps réel.
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) {
        // Cas classique : format natif Firestore
        return date.toDate();
      } else if (date is int) {
        // Cas de secours : format entier (millisecondes)
        return DateTime.fromMillisecondsSinceEpoch(date);
      } else {
        // Valeur par défaut pour éviter les erreurs "null"
        return DateTime.now();
      }
    }

    return UserModel(
      // Utilisation de l'opérateur '??' pour fournir une valeur par défaut si le champ est vide
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: parseDate(map['lastSeen']), // Traitement sécurisé de la date
      fcmToken: map['fcmToken'] ?? '',
      
    );
  }
}*/



import 'package:cloud_firestore/cloud_firestore.dart';

/// Cette classe représente l'utilisateur au sein de l'application.
class UserModel {
  // Identifiant unique généré par Firebase Auth
  final String uid;
  
  // Informations de profil de l'utilisateur
  final String name;
  final String email;
  final String photoUrl; // URL de l'image stockée dans Firebase Storage
  
  // Gestion de la présence en temps réel
  final bool isOnline; // Statut : en ligne (true) ou hors ligne (false)
  final DateTime lastSeen; // Horodatage de la dernière activité

  // --- NOUVEAU CHAMP : PRIORITÉ DE LA LISTE ---
  // On utilise 'dynamic' car il peut être un int ou un Timestamp au début
  final dynamic lastMessageTime; 
  
  // Token pour les notifications push
  final String fcmToken;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isOnline,
    required this.lastSeen,
    this.lastMessageTime, // Optionnel au début
    this.fcmToken = "",
  });

  /// Convertit l'objet UserModel en Map (JSON) pour Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'lastMessageTime': lastMessageTime, // Sauvegarde du temps du dernier message
      'fcmToken': fcmToken,
    };
  }

  /// Crée une instance de UserModel à partir des données reçues de Firestore.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    
    /// Fonction interne de sécurité pour gérer les dates (lastSeen).
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is int) {
        return DateTime.fromMillisecondsSinceEpoch(date);
      } else {
        return DateTime.now();
      }
    }

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: parseDate(map['lastSeen']),
      
      // --- RÉCUPÉRATION DU NOUVEAU CHAMP ---
      // On récupère la valeur brute (int ou Timestamp)
      lastMessageTime: map['lastMessageTime'], 
      
      fcmToken: map['fcmToken'] ?? '',
    );
  }
}