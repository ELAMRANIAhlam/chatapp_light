/*import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ProfilePage extends StatelessWidget {
  final UserModel user;
  const ProfilePage({super.key, required this.user});

  // Fonction pour gérer l'affichage de l'image (identique à votre UsersPage)
  ImageProvider _getImage(String photoData, String name) {
    if (photoData.startsWith('http')) return NetworkImage(photoData);
    try {
      return MemoryImage(base64Decode(photoData));
    } catch (e) {
      return NetworkImage("https://ui-avatars.com/api/?name=$name");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mon Profil")),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 70,
              backgroundImage: _getImage(user.photoUrl, user.name),
            ),
            const SizedBox(height: 20),
            Text(
              user.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              user.email,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            // Vous pouvez ajouter d'autres infos ici
          ],
        ),
      ),
    );
  }
}*/




import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ProfilePage extends StatelessWidget {
  final UserModel user;
  const ProfilePage({super.key, required this.user});

  // Fonction pour gérer l'affichage de l'image (Base64 ou URL)
  ImageProvider _getImage(String photoData, String name) {
    if (photoData.startsWith('http')) return NetworkImage(photoData);
    try {
      return MemoryImage(base64Decode(photoData));
    } catch (e) {
      return NetworkImage("https://ui-avatars.com/api/?name=$name");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack( // Utilisation de Stack pour placer le bouton de retour par-dessus
          children: [
            // Bouton de retour en haut à gauche
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),

            ),
            
            // Contenu principal
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                String name = user.name;
                String email = user.email;
                String photoUrl = user.photoUrl;

                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  name = data['name'] ?? name;
                  email = data['email'] ?? email;
                  photoUrl = data['photoUrl'] ?? photoUrl;
                }

                return Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      
                      const Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 40),

                      // Avatar avec halo bleu
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue.shade100, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 75,
                          backgroundImage: _getImage(photoUrl, name),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}