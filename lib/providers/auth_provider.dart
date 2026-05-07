import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // INDISPENSABLE pour les notifications [cite: 81]

/// Classe AuthProvider utilisant le mixin ChangeNotifier pour notifier l'UI des changements d'état.
/// Elle implémente la logique d'authentification demandée dans le cahier des charges[cite: 27, 90].
class AuthProvider with ChangeNotifier {
  // Instances des services Firebase nécessaires
  final FirebaseAuth _auth = FirebaseAuth.instance; // Pour l'authentification (email/mdp) [cite: 86]
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Pour stocker les données utilisateurs [cite: 87]
  final FirebaseMessaging _messaging = FirebaseMessaging.instance; // Instance Cloud Messaging pour les notifications [cite: 81]
  
  bool _isLoading = false; // État de chargement pour l'affichage de l'UI [cite: 90]

  bool get isLoading => _isLoading;

  // --- FONCTION PRIVÉE POUR LE TOKEN FCM ---
  /// Récupère et enregistre le jeton de notification unique de l'appareil dans Firestore.
  Future<void> _updateToken(String uid) async {
    try {
      // Récupère le token unique de l'appareil (nécessaire pour envoyer des messages ciblés)
      String? token = await _messaging.getToken();
      if (token != null) {
        // Mise à jour du document utilisateur dans la collection "users" [cite: 34]
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      print("Erreur lors de la mise à jour du token: $e");
    }
  }

  // INSCRIPTION
  /// Gère la création de compte, le traitement de l'image de profil et l'initialisation des données[cite: 29].
  Future<String?> registerUser({
    required String email,
    required String password,
    required String name,
    XFile? imageXFile, 
  }) async {
    _isLoading = true;
    notifyListeners(); // Informe les widgets de l'état de chargement [cite: 90]

    try {
      // 1. Création du compte utilisateur dans Firebase Authentication [cite: 29]
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      String photoData = ""; 

      // 2. Traitement de l'image de profil
      if (imageXFile != null) {
        // Conversion de l'image en Base64 pour un stockage direct (Alternative à Storage)
        Uint8List imageBytes = await imageXFile.readAsBytes();
        photoData = base64Encode(imageBytes); 
      } else {
        // Génération d'un avatar par défaut avec les initiales si aucune image n'est choisie 
        photoData = "https://ui-avatars.com/api/?name=${name.replaceAll(' ', '+')}&background=2196F3&color=fff";
      }

      // 3. Création du document dans la collection "users" de Firestore [cite: 34]
      await _firestore.collection('users').doc(userCred.user!.uid).set({
        'uid': userCred.user!.uid,
        'name': name.trim(),
        'email': email.trim(),
        'photoUrl': photoData, 
        'isOnline': true, // L'utilisateur est connecté par défaut à l'inscription [cite: 62]
        'lastSeen': FieldValue.serverTimestamp(), // Date exacte du serveur [cite: 63]
        'fcmToken': "", // Sera rempli par l'appel à _updateToken juste après
      });

      // 4. RÉCUPÉRATION DU TOKEN POUR LES NOTIFICATIONS
      // Permet de lier l'appareil actuel au compte utilisateur pour les notifications push [cite: 81]
      await _updateToken(userCred.user!.uid);

      _isLoading = false;
      notifyListeners();
      return "SUCCESS";
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      // Gestion des erreurs courantes d'authentification 
      if (e.code == 'email-already-in-use') return "Cet utilisateur existe déjà.";
      if (e.code == 'weak-password') return "Mot de passe trop court.";
      return e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  // CONNEXION
  /// Gère l'authentification des utilisateurs existants et met à jour leur statut[cite: 30].
  Future<String?> loginUser(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Authentification par email et mot de passe [cite: 30]
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      // Mise à jour du statut "en ligne" dans Firestore [cite: 63]
      await _firestore.collection('users').doc(userCred.user!.uid).update({
        'isOnline': true,
      });

      // RÉACTUALISATION DU TOKEN FCM (Sécurité si l'utilisateur change d'appareil) [cite: 81]
      await _updateToken(userCred.user!.uid);

      _isLoading = false;
      notifyListeners();
      return null; // Pas d'erreur
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return "Email ou mot de passe incorrect.";
    }
  }

  // DÉCONNEXION
  /// Déconnecte l'utilisateur et met à jour son statut "hors ligne"[cite: 31, 63].
  Future<void> logout() async {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Marque l'utilisateur comme déconnecté dans Firestore [cite: 63]
      await _firestore.collection('users').doc(uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(), // Enregistre le moment de la dernière connexion [cite: 63]
      });
    }
    // Fermeture de la session Firebase Auth [cite: 31]
    await _auth.signOut();
    notifyListeners();
  }
}