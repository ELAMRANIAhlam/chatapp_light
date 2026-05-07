import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth_theme.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  XFile? _pickedFile;

  // Sélection d'image optimisée
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,      
      maxHeight: 512,     
      imageQuality: 70,   
    );

    if (image != null) {
      setState(() {
        _pickedFile = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Text(
              "Créer un compte",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 10),
            const Text(
              "Rejoignez-nous pour commencer à discuter",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            
            // Avatar avec icône Bleue
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Color(0xFF5AB6B9).withOpacity(0.1),
                backgroundImage: _pickedFile != null
                    ? FileImage(File(_pickedFile!.path))
                    : null,
                child: _pickedFile == null
                    ? const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF5AB6B9)) // CHANGÉ EN BLEU
                    : null,
              ),
            ),

            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: AuthTheme.inputDecoration("Nom complet"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: AuthTheme.inputDecoration("Email"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: AuthTheme.inputDecoration("Mot de passe"),
            ),
            const SizedBox(height: 30),

            // Bouton S'inscrire en Bleue
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5AB6B9), // CHANGÉ EN BLEU
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        if (_emailController.text.isEmpty || _nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Veuillez remplir tous les champs")),
                          );
                          return;
                        }

                        String? result = await authProvider.registerUser(
                          email: _emailController.text,
                          password: _passwordController.text,
                          name: _nameController.text,
                          imageXFile: _pickedFile,
                        );

                        if (result == "SUCCESS") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Bien enregistré ! Veuillez vous connecter."),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result ?? "Erreur inconnue"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: authProvider.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "S'INSCRIRE",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            // Lien vers LOGIN en Bleue
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Déjà un compte ? "),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text(
                    "Se connecter",
                    style: TextStyle(
                      color: Color(0xFF5AB6B9), // CHANGÉ EN BLEU
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}