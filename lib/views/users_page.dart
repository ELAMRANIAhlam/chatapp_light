/*import 'dart:convert';
import 'package:chatapp_light/views/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';
import '../providers/auth_provider.dart' as my_auth;
import '../providers/theme_provider.dart';
import 'chat_page.dart';
import 'group_chat_page.dart';
import 'create_group_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String searchQuery = "";
  int _selectedIndex = 0;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  void _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null && currentUserId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({'fcmToken': token});
      }
    }
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.notification?.title ?? "Nouveau message", 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(message.notification?.body ?? ""),
              ],
            ),
            backgroundColor: const Color(0xFF5AB6B9),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 150,
              left: 10,
              right: 10,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  String _getChatId(String u1, String u2) {
    List<String> ids = [u1, u2];
    ids.sort();
    return ids.join("_");
  }

  void _logout(my_auth.AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment quitter l'application ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              if (currentUserId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .update({
                      'isOnline': false,
                      'lastSeen': DateTime.now().millisecondsSinceEpoch,
                    });
              }
              await authProvider.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text("Déconnexion", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<my_auth.AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? "Messages" : (_selectedIndex == 1 ? "Groupes" : "Paramètres"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _logout(authProvider),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [_buildUsersList(), _buildGroupsList(), _buildSettingsPage()],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF5AB6B9),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateGroupPage()),
              ),
              child: const Icon(Icons.group_add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF5AB6B9),
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Privé'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'Groupes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Paramètres'),
        ],
      ),
    );
  }

  // --- LISTE DES CONTACTS (TRIÉE PAR PRIORITÉ DE MESSAGE) ---
  Widget _buildUsersList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Rechercher un contact...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // CHANGEMENT ICI : On trie par 'lastInteraction' au lieu de 'lastSeen'
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('lastInteraction', descending: true) 
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var users = snapshot.data!.docs
                  .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                  .where((u) => u.uid != currentUserId && u.name.toLowerCase().contains(searchQuery))
                  .toList();

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  String chatId = _getChatId(currentUserId, user.uid);

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, msgSnapshot) {
                      String lastMsgText = user.isOnline ? "En ligne" : "Hors ligne";
                      int unreadCount = 0;

                      if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                        var lastDoc = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        if (lastDoc['type'] == 1) lastMsgText = "📷 Image";
                        else if (lastDoc['type'] == 2) lastMsgText = "🎤 Message vocal";
                        else lastMsgText = lastDoc['message'] ?? "";

                        unreadCount = msgSnapshot.data!.docs.where((d) {
                          var data = d.data() as Map<String, dynamic>;
                          return data['receiverId'] == currentUserId && data['isRead'] == false;
                        }).length;
                      }

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage: _getImage(user.photoUrl, user.name),
                              radius: 25,
                            ),
                            if (user.isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          lastMsgText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) : Colors.grey,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty
                                  ? DateFormat('HH:mm').format(
                                      (msgSnapshot.data!.docs.first.data() as Map<String, dynamic>)['timestamp'].toDate()
                                    )
                                  : "", // Ila mkanch message, khallih khawi
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            if (unreadCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: const Color(0xFF5AB6B9),
                                  child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ChatPage(receiver: user)),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- RESTE DES WIDGETS (GROUPES, PARAMETRES, GETIMAGE) ---
  Widget _buildGroupsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final groups = snapshot.data!.docs;
        if (groups.isEmpty) return const Center(child: Text("Aucun groupe."));

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = GroupModel.fromMap(groups[index].data() as Map<String, dynamic>);
            return ListTile(
              leading: CircleAvatar(backgroundImage: _getImage(group.groupIcon, group.groupName)),
              title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(group.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GroupChatPage(group: group)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsPage() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final userData = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSettingsTile(
                icon: Icons.person_outline,
                title: "Mon profil",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage(user: userData))),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF5AB6B9)),
                  title: const Text("Mode Sombre"),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    activeColor: const Color(0xFF5AB6B9),
                    onChanged: (val) => themeProvider.toggleTheme(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF5AB6B9)),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  ImageProvider _getImage(String photoData, String name) {
    if (photoData.startsWith('http')) return NetworkImage(photoData);
    try {
      return MemoryImage(base64Decode(photoData));
    } catch (e) {
      return NetworkImage("https://ui-avatars.com/api/?name=$name");
    }
  }
}*/


import 'dart:convert';
import 'package:chatapp_light/views/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../models/group_model.dart';
import '../providers/auth_provider.dart' as my_auth;
import '../providers/theme_provider.dart';
import 'chat_page.dart';
import 'group_chat_page.dart';
import 'create_group_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String searchQuery = "";
  int _selectedIndex = 0;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  void _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null && currentUserId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({'fcmToken': token});
      }
    }
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.notification?.title ?? "Nouveau messageeee", 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(message.notification?.body ?? ""),
              ],
            ),
            backgroundColor: const Color(0xFF5AB6B9),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 150,
              left: 10,
              right: 10,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  String _getChatId(String u1, String u2) {
    List<String> ids = [u1, u2];
    ids.sort();
    return ids.join("_");
  }

  void _logout(my_auth.AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment quitter l'application ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              if (currentUserId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .update({
                      'isOnline': false,
                      'lastSeen': DateTime.now().millisecondsSinceEpoch,
                    });
              }
              await authProvider.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text("Déconnexion", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<my_auth.AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? "Messages" : (_selectedIndex == 1 ? "Groupes" : "Paramètres"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _logout(authProvider),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [_buildUsersList(), _buildGroupsList(), _buildSettingsPage()],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF5AB6B9),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateGroupPage()),
              ),
              child: const Icon(Icons.group_add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF5AB6B9),
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Privé'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'Groupes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Paramètres'),
        ],
      ),
    );
  }

  // --- LISTE DES CONTACTS (TRIÉE PAR PRIORITÉ DE MESSAGE) ---
  /*Widget _buildUsersList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Rechercher un contact...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // CHANGEMENT ICI : On trie par 'lastInteraction' au lieu de 'lastSeen'
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('lastInteraction', descending: true) 
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var users = snapshot.data!.docs
                  .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                  .where((u) => u.uid != currentUserId && u.name.toLowerCase().contains(searchQuery))
                  .toList();

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  String chatId = _getChatId(currentUserId, user.uid);

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, msgSnapshot) {
                      String lastMsgText = user.isOnline ? "En ligne" : "Hors ligne";
                      int unreadCount = 0;

                      if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                        var lastDoc = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        if (lastDoc['type'] == 1) lastMsgText = "📷 Image";
                        else if (lastDoc['type'] == 2) lastMsgText = "🎤 Message vocal";
                        else lastMsgText = lastDoc['message'] ?? "";

                        unreadCount = msgSnapshot.data!.docs.where((d) {
                          var data = d.data() as Map<String, dynamic>;
                          return data['receiverId'] == currentUserId && data['isRead'] == false;
                        }).length;
                      }

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage: _getImage(user.photoUrl, user.name),
                              radius: 25,
                            ),
                            if (user.isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          lastMsgText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) : Colors.grey,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty
                                  ? DateFormat('HH:mm').format(
                                      (msgSnapshot.data!.docs.first.data() as Map<String, dynamic>)['timestamp'].toDate()
                                    )
                                  : "", // Ila mkanch message, khallih khawi
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            if (unreadCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: const Color(0xFF5AB6B9),
                                  child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ChatPage(receiver: user)),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }*/


  // --- LISTE DES CONTACTS (MISE À JOUR : TRI LOCAL POUR ÉVITER LES CONTACTS MASQUÉS) ---
  Widget _buildUsersList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Rechercher un contact...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // On retire le .orderBy d'ici pour que TOUS les users soient chargés
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Erreur de chargement"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              // 1. Transformer les documents en liste de UserModel
              List<UserModel> users = snapshot.data!.docs
                  .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                  .where((u) => u.uid != currentUserId && u.name.toLowerCase().contains(searchQuery))
                  .toList();

              // 2. TRIER LA LISTE MANUELLEMENT
              // On place ceux qui ont le 'lastMessageTime' le plus récent en premier
              // 2. TRIER LA LISTE MANUELLEMENT
              users.sort((a, b) {
                // Fonction interne pour convertir n'importe quel format (Timestamp ou int) en millisecondes
                int getTime(dynamic lastTime) {
                  if (lastTime == null) return 0;
                  if (lastTime is Timestamp) return lastTime.millisecondsSinceEpoch;
                  if (lastTime is int) return lastTime;
                  return 0;
                }

                int timeA = getTime(a.lastMessageTime);
                int timeB = getTime(b.lastMessageTime);

                return timeB.compareTo(timeA); // Tri décroissant (plus récent en haut)
              });

              if (users.isEmpty) return const Center(child: Text("Aucun contact trouvé"));

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  String chatId = _getChatId(currentUserId, user.uid);

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, msgSnapshot) {
                      String lastMsgText = user.isOnline ? "En ligne" : "Hors ligne";
                      int unreadCount = 0;
                      DateTime? lastMsgDate;

                      if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                        var lastDoc = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        
                        // Texte du dernier message
                        if (lastDoc['type'] == 1) lastMsgText = "📷 Image";
                        else if (lastDoc['type'] == 2) lastMsgText = "🎤 Message vocal";
                        else lastMsgText = lastDoc['message'] ?? "";

                        // Date du dernier message
                        if (lastDoc['timestamp'] != null) {
                          lastMsgDate = (lastDoc['timestamp'] as Timestamp).toDate();
                        }

                        // Messages non lus
                        unreadCount = msgSnapshot.data!.docs.where((d) {
                          var data = d.data() as Map<String, dynamic>;
                          return data['receiverId'] == currentUserId && data['isRead'] == false;
                        }).length;
                      }

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage: _getImage(user.photoUrl, user.name),
                              radius: 25,
                            ),
                            if (user.isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          lastMsgText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) : Colors.grey,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              lastMsgDate != null ? DateFormat('HH:mm').format(lastMsgDate) : "",
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            if (unreadCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: const Color(0xFF5AB6B9),
                                  child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ChatPage(receiver: user)),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- RESTE DES WIDGETS (GROUPES, PARAMETRES, GETIMAGE) ---
  Widget _buildGroupsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final groups = snapshot.data!.docs;
        if (groups.isEmpty) return const Center(child: Text("Aucun groupe."));

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = GroupModel.fromMap(groups[index].data() as Map<String, dynamic>);
            return ListTile(
              leading: CircleAvatar(backgroundImage: _getImage(group.groupIcon, group.groupName)),
              title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(group.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GroupChatPage(group: group)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsPage() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final userData = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSettingsTile(
                icon: Icons.person_outline,
                title: "Mon profil",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage(user: userData))),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF5AB6B9)),
                  title: const Text("Mode Sombre"),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    activeColor: const Color(0xFF5AB6B9),
                    onChanged: (val) => themeProvider.toggleTheme(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF5AB6B9)),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  ImageProvider _getImage(String photoData, String name) {
    if (photoData.startsWith('http')) return NetworkImage(photoData);
    try {
      return MemoryImage(base64Decode(photoData));
    } catch (e) {
      return NetworkImage("https://ui-avatars.com/api/?name=$name");
    }
  }
}