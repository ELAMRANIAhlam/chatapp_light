import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import '../providers/auth_provider.dart'; 
import 'auth_theme.dart';
import 'register_page.dart'; 

class LoginScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(
              Icons.chat_bubble_rounded,
              size: 60,
              // CHANGÉ : Icône en bleu
              color: Color(0xFF5AB6B9), 
            ),
            const SizedBox(height: 10),
            const Text(
              "ChatApp Light",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // Toggle Bar
            Row(
              children: [
                Expanded(child: _topTab("Se connecter", true)),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RegisterScreen()),
                    ),
                    child: _topTab("S'inscrire", false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
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
            
            _actionButton(
              authProvider.isLoading ? "Connexion..." : "Se connecter", 
              authProvider.isLoading ? null : () async {
                if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Veuillez remplir tous les champs")),
                  );
                  return;
                }

                String? result = await authProvider.loginUser(
                  _emailController.text.trim(),
                  _passwordController.text.trim(),
                );

                if (result != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result), backgroundColor: Colors.red),
                  );
                }
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _topTab(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        // CHANGÉ : Couleur d'onglet actif en bleu
        color: active ? Color(0xFF5AB6B9) : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey, 
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String text, VoidCallback? onTap) {
  return InkWell(
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          // CHANGÉ : Dégradé bleu pour le bouton
          gradient: const LinearGradient(
            colors: [Color(0xFF5AB6B9), Color(0xFF5AB6B9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    ),
  );
}
}