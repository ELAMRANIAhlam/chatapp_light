import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  List<String> selectedUserIds = [];
  String? base64Image; 
  bool isCreating = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        base64Image = base64Encode(bytes);
      });
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez donner un nom au groupe")),
      );
      return;
    }
    
    setState(() => isCreating = true);
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance.collection('groups').doc();

      List<String> allMembers = [currentUserId, ...selectedUserIds];

      final newGroup = GroupModel(
        groupId: docRef.id,
        groupName: _groupNameController.text.trim(),
        groupIcon: base64Image ?? "https://ui-avatars.com/api/?name=${_groupNameController.text}",
        members: allMembers,
        lastMessage: "Groupe créé",
        lastMessageTime: DateTime.now(),
      );

      await docRef.set(newGroup.toMap());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Erreur création groupe: $e");
    } finally {
      setState(() => isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Créer un groupe"),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 25),
          
          // --- SÉLECTION DE LA PHOTO ---
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                  backgroundImage: base64Image != null 
                      ? MemoryImage(base64Decode(base64Image!)) 
                      : null,
                  child: base64Image == null 
                      ? Icon(Icons.group, size: 50, color: isDark ? Colors.white54 : Colors.white) 
                      : null,
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF5AB6B9),
                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                ),
              ],
            ),
          ),

          // --- CHAMP NOM DU GROUPE ---
          Padding(
            padding: const EdgeInsets.all(25),
            child: TextField(
              controller: _groupNameController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Nom du groupe",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                prefixIcon: const Icon(Icons.edit, color: Color(0xFF5AB6B9)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              children: [
                Text(
                  "Ajouter des membres (${selectedUserIds.length})",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // --- LISTE DES UTILISATEURS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final currentId = FirebaseAuth.instance.currentUser!.uid;
                var users = snapshot.data!.docs
                    .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                    .where((u) => u.uid != currentId).toList();

                return ListView.separated(
                  itemCount: users.length,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  separatorBuilder: (context, index) => const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    bool isSelected = selectedUserIds.contains(user.uid);

                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CheckboxListTile(
                        activeColor: const Color(0xFF5AB6B9),
                        checkColor: Colors.white,
                        title: Text(
                          user.name,
                          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        ),
                        secondary: CircleAvatar(
                          backgroundImage: user.photoUrl.isNotEmpty 
                              ? (user.photoUrl.startsWith('http') 
                                  ? NetworkImage(user.photoUrl) 
                                  : MemoryImage(base64Decode(user.photoUrl)) as ImageProvider)
                              : null,
                          child: user.photoUrl.isEmpty ? Text(user.name[0]) : null,
                        ),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            val! ? selectedUserIds.add(user.uid) : selectedUserIds.remove(user.uid);
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      
      // --- BOUTON DE VALIDATION ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF5AB6B9),
        onPressed: isCreating ? null : _createGroup,
        child: isCreating 
            ? const CircularProgressIndicator(color: Colors.white) 
            : const Icon(Icons.check, color: Colors.white, size: 30),
      ),
    );
  }
}