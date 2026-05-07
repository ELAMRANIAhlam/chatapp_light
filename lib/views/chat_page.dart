import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class ChatPage extends StatefulWidget {
  final UserModel receiver;
  const ChatPage({super.key, required this.receiver});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  Timer? _typingTimer;

  // AJOUT pour stabiliser le flux
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    // On initialise le stream une seule fois pour éviter les rebuilds constants
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(getChatId())
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _setTypingStatus("none");
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  // --- LOGIQUE DE CHAT ---

  String getChatId() {
    List<String> ids = [currentUserId, widget.receiver.uid];
    ids.sort();
    return ids.join("_");
  }

  void _setTypingStatus(String status) {
    FirebaseFirestore.instance.collection('chats').doc(getChatId()).set({
      'typingStatus': {currentUserId: status}
    }, SetOptions(merge: true));
  }

  void _onTextChanged(String value) {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _setTypingStatus("text");
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTypingStatus("none");
    });
    setState(() {});
  }

  String _formatStatus(bool isOnline, DateTime lastSeen, dynamic typingStatus) {
    if (typingStatus == "text") return "En train d'écrire...";
    if (typingStatus == "audio") return "Enregistre un audio...";
    if (isOnline) return "En ligne";
    
    final now = DateTime.now();
    final hourMin = DateFormat('HH:mm').format(lastSeen);
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
    final difference = today.difference(lastDate).inDays;

    if (difference == 0) return "En ligne aujourd'hui à $hourMin";
    if (difference == 1) return "En ligne hier à $hourMin";
    return "En ligne le ${DateFormat('dd/MM à HH:mm').format(lastSeen)}";
  }

  // --- ENVOI DE MESSAGES & PRIORITÉ ---

  /*void _sendMessage({String? content, MessageType type = MessageType.text}) async {
    String messageContent = content ?? _messageController.text.trim();
    if (messageContent.isEmpty && type == MessageType.text) return;

    _setTypingStatus("none");

    // 1. On crée le message (isRead est à false par défaut)
    final msg = MessageModel(
      senderId: currentUserId,
      receiverId: widget.receiver.uid,
      message: messageContent,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      hiddenFor: [],
    );

    if (type == MessageType.text) {
      _messageController.clear();
      setState(() {});
    }

    // 2. Sauvegarde dans Firestore
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(getChatId())
        .collection('messages')
        .add(msg.toMap());

    // 3. RÉCUPÉRER VOTRE NOM pour la notification
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    String myName = myDoc.data()?['name'] ?? "Quelqu'un";

    // 4. Mettre à jour la date pour que la conversation remonte en haut
    final int nowTimestamp = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({'lastInteraction': nowTimestamp});
    await FirebaseFirestore.instance.collection('users').doc(widget.receiver.uid).update({'lastInteraction': nowTimestamp});

    // 5. ENVOYER LA NOTIFICATION avec votre nom
    if (widget.receiver.fcmToken.isNotEmpty) {
      String preview = (type == MessageType.image) ? "📷 Image" : (type == MessageType.audio ? "🎤 Vocal" : messageContent);
      
      // Ici on utilise 'myName' au lieu de "Nouveau message"
      NotificationService.sendNotification(widget.receiver.fcmToken, myName, preview);
    }
  }*/

  // --- ENVOI DE MESSAGES & PRIORITÉ ---

  // --- ENVOI DE MESSAGES & PRIORITÉ ---

  void _sendMessage({String? content, MessageType type = MessageType.text}) async {
    String messageContent = content ?? _messageController.text.trim();
    if (messageContent.isEmpty && type == MessageType.text) return;

    _setTypingStatus("none");

    // 1. On crée le message
    final msg = MessageModel(
      senderId: currentUserId,
      receiverId: widget.receiver.uid,
      message: messageContent,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      hiddenFor: [],
    );

    if (type == MessageType.text) {
      _messageController.clear();
      setState(() {});
    }

    // 2. Sauvegarde dans Firestore (La collection des messages)
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(getChatId())
        .collection('messages')
        .add(msg.toMap());

    // 3. RÉCUPÉRER VOTRE NOM pour la notification
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    String myName = myDoc.data()?['name'] ?? "Quelqu'un";

    // --- 4. MISE À JOUR DU CHAMP POUR LE TRI (INDISPENSABLE) ---
    // On utilise un format numérique (int) pour que le .sort() dans UsersPage fonctionne parfaitement
    final int now = DateTime.now().millisecondsSinceEpoch;
    
    final updateData = {
      'lastMessageTime': now, 
    };
    
    // On met à jour les deux utilisateurs pour que la discussion remonte chez l'un comme chez l'autre
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).update(updateData);
    await FirebaseFirestore.instance.collection('users').doc(widget.receiver.uid).update(updateData);

    // 5. ENVOYER LA NOTIFICATION
    if (widget.receiver.fcmToken.isNotEmpty) {
      String preview = (type == MessageType.image) ? "📷 Image" : (type == MessageType.audio ? "🎤 Vocal" : messageContent);
      NotificationService.sendNotification(widget.receiver.fcmToken, myName, preview);
    }
  }

  // --- ACTIONS MEDIA ---

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery, 
      imageQuality: 40,
      maxWidth: 800,
      maxHeight: 800
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      _sendMessage(content: base64Encode(bytes), type: MessageType.image);
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      _setTypingStatus("audio");
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    _setTypingStatus("none");
    setState(() => _isRecording = false);
    if (path != null) {
      final bytes = await File(path).readAsBytes();
      _sendMessage(content: base64Encode(bytes), type: MessageType.audio);
    }
  }

  // --- GESTION MESSAGES ---

  void _showOptions(MessageModel msg, String messageId) {
    if (msg.isDeleted) return;
    bool isMe = msg.senderId == currentUserId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (isMe && msg.type == MessageType.text)
              ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text("Modifier"),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(msg, messageId);
                  }),
            ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.orange),
                title: const Text("Supprimer pour moi"),
                onTap: () {
                  Navigator.pop(context);
                  _deleteForMe(messageId);
                }),
            if (isMe)
              ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text("Supprimer pour tous"),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteForEveryone(messageId);
                  }),
          ],
        ),
      ),
    );
  }

  void _deleteForMe(String id) => FirebaseFirestore.instance.collection('chats').doc(getChatId()).collection('messages').doc(id).update({
        'hiddenFor': FieldValue.arrayUnion([currentUserId])
      });

  void _deleteForEveryone(String id) => FirebaseFirestore.instance.collection('chats').doc(getChatId()).collection('messages').doc(id).update({
        'isDeleted': true,
        'message': "Ce message a été supprimé",
        'type': MessageType.text.index
      });

  void _showEditDialog(MessageModel msg, String id) {
    TextEditingController ctrl = TextEditingController(text: msg.message);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier"),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  FirebaseFirestore.instance.collection('chats').doc(getChatId()).collection('messages').doc(id).update({'message': ctrl.text.trim(), 'isEdited': true});
                  Navigator.pop(context);
                }
              },
              child: const Text("OK")),
        ],
      ),
    );
  }

  // --- INTERFACE (UI) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5AB6B9),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.receiver.uid).snapshots(),
          builder: (context, userSnap) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(getChatId()).snapshots(),
              builder: (context, chatSnap) {
                bool isOnline = false;
                DateTime lastSeen = DateTime.now();
                dynamic typingStatus = "none";

                if (userSnap.hasData && userSnap.data!.exists) {
                  var data = userSnap.data!.data() as Map<String, dynamic>;
                  isOnline = data['isOnline'] ?? false;
                  lastSeen = (data['lastSeen'] is Timestamp) 
                      ? (data['lastSeen'] as Timestamp).toDate() 
                      : DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] ?? 0);
                }

                if (chatSnap.hasData && chatSnap.data!.exists) {
                  var chatData = chatSnap.data!.data() as Map<String, dynamic>;
                  typingStatus = chatData['typingStatus']?[widget.receiver.uid] ?? "none";
                }

                bool isActiveAction = typingStatus == "text" || typingStatus == "audio";

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: _getImage(widget.receiver.photoUrl, widget.receiver.name)
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.receiver.name, 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(
                            height: 16,
                            child: Text(
                              _formatStatus(isOnline, lastSeen, typingStatus), 
                              style: TextStyle(
                                fontSize: 11, 
                                color: isActiveAction ? Colors.yellowAccent : Colors.white70,
                                fontWeight: isActiveAction ? FontWeight.bold : FontWeight.normal
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage("assets/chat_bg.png"), fit: BoxFit.cover, opacity: 0.05),
        ),
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      // Utilisation du stream initialisé dans initState pour la stabilité
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return !(data['hiddenFor'] ?? []).contains(currentUserId);
        }).toList();

        // SOLUTION AU PROBLEME : Marquer comme lu de manière asynchrone hors du build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markMessagesAsRead(allDocs);
        });

        return ListView.builder(
          reverse: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final msg = MessageModel.fromMap(docs[index].data() as Map<String, dynamic>);
            return GestureDetector(
              onLongPress: () => _showOptions(msg, docs[index].id), 
              child: _buildMessageBubble(msg)
            );
          },
        );
      },
    );
  }

  // Fonction pour marquer comme lu sans faire clignoter la page
  void _markMessagesAsRead(List<QueryDocumentSnapshot> docs) {
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['receiverId'] == currentUserId && data['isRead'] == false) {
        doc.reference.update({'isRead': true});
      }
    }
  }

  Widget _buildMessageBubble(MessageModel msg) {
    bool isMe = msg.senderId == currentUserId;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.all(8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE1FFC7) : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.type == MessageType.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(base64Decode(msg.message), fit: BoxFit.cover),
              ),
            if (msg.type == MessageType.text)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(msg.message, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15)),
              ),
            if (msg.type == MessageType.audio)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: Color(0xFF5AB6B9), size: 32),
                    onPressed: () => _audioPlayer.play(BytesSource(base64Decode(msg.message))),
                  ),
                  const Text("Message vocal", style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.isEdited) const Text("modifié ", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                Text(DateFormat('HH:mm').format(msg.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all, size: 15, color: msg.isRead ? Colors.blue : Colors.grey),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    bool isTextEmpty = _messageController.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: _pickImage),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTextChanged,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        hintText: "Message",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isTextEmpty ? null : () => _sendMessage(),
            onLongPress: isTextEmpty ? _startRecording : null,
            onLongPressUp: isTextEmpty ? _stopRecording : null,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: _isRecording ? Colors.red : const Color(0xFF00A884),
              child: Icon(
                isTextEmpty ? (_isRecording ? Icons.stop : Icons.mic) : Icons.send,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _getImage(String photoData, String name) {
    if (photoData.isEmpty) return NetworkImage("https://ui-avatars.com/api/?name=$name&background=5AB6B9&color=fff");
    if (photoData.startsWith('http')) return NetworkImage(photoData);
    try {
      return MemoryImage(base64Decode(photoData));
    } catch (e) {
      return NetworkImage("https://ui-avatars.com/api/?name=$name");
    }
  }
}




/*import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class ChatPage extends StatefulWidget {
  final UserModel receiver;
  const ChatPage({super.key, required this.receiver});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  Timer? _typingTimer;

  @override
  void dispose() {
    _setTypingStatus("none");
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  // --- LOGIQUE DE CHAT ---

  String getChatId() {
    List<String> ids = [currentUserId, widget.receiver.uid];
    ids.sort();
    return ids.join("_");
  }

  void _setTypingStatus(String status) {
    FirebaseFirestore.instance.collection('chats').doc(getChatId()).set({
      'typingStatus': {currentUserId: status}
    }, SetOptions(merge: true));
  }

  void _onTextChanged(String value) {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _setTypingStatus("text");
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTypingStatus("none");
    });
    setState(() {});
  }

  String _formatStatus(bool isOnline, DateTime lastSeen, dynamic typingStatus) {
    if (typingStatus == "text") return "En train d'écrire...";
    if (typingStatus == "audio") return "Enregistre un audio...";
    if (isOnline) return "En ligne";
    
    final now = DateTime.now();
    final hourMin = DateFormat('HH:mm').format(lastSeen);
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
    final difference = today.difference(lastDate).inDays;

    if (difference == 0) return "En ligne aujourd'hui à $hourMin";
    if (difference == 1) return "En ligne hier à $hourMin";
    return "En ligne le ${DateFormat('dd/MM à HH:mm').format(lastSeen)}";
  }

// --- LOGIQUE D'ENVOI ---
  void _sendMessage({
    String? content,
    MessageType type = MessageType.text,
  }) async {
    String messageContent = content ?? _messageController.text.trim();
    if (messageContent.isEmpty && type == MessageType.text) return;

    final msg = MessageModel(
      senderId: currentUserId,
      receiverId: widget.receiver.uid,
      message: messageContent,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      hiddenFor: [],
    );

    if (type == MessageType.text) _messageController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(getChatId())
        .collection('messages')
        .add(msg.toMap());

    if (widget.receiver.fcmToken.isNotEmpty) {
      String preview = (type == MessageType.image)
          ? "📷 Image"
          : (type == MessageType.audio ? "🎤 Message vocal" : messageContent);
      NotificationService.sendNotification(
        widget.receiver.fcmToken,
        "Message de ${FirebaseAuth.instance.currentUser?.displayName ?? 'Contact'}",
        preview,
      );
    }
  }




  // --- ACTIONS MEDIA ---

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery, 
      imageQuality: 40,
      maxWidth: 800,
      maxHeight: 800
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      _sendMessage(content: base64Encode(bytes), type: MessageType.image);
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      _setTypingStatus("audio");
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    _setTypingStatus("none");
    setState(() => _isRecording = false);
    if (path != null) {
      final bytes = await File(path).readAsBytes();
      _sendMessage(content: base64Encode(bytes), type: MessageType.audio);
    }
  }

  // --- GESTION MESSAGES ---

  void _showOptions(MessageModel msg, String messageId) {
    if (msg.isDeleted) return;
    bool isMe = msg.senderId == currentUserId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (isMe && msg.type == MessageType.text)
              ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text("Modifier"),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(msg, messageId);
                  }),
            ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.orange),
                title: const Text("Supprimer pour moi"),
                onTap: () {
                  Navigator.pop(context);
                  _deleteForMe(messageId);
                }),
            if (isMe)
              ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text("Supprimer pour tous"),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteForEveryone(messageId);
                  }),
          ],
        ),
      ),
    );
  }

  void _deleteForMe(String id) => FirebaseFirestore.instance.collection('chats').doc(getChatId()).collection('messages').doc(id).update({
        'hiddenFor': FieldValue.arrayUnion([currentUserId])
      });

  void _deleteForEveryone(String id) => FirebaseFirestore.instance.collection('chats').doc(getChatId()).collection('messages').doc(id).update({
        'isDeleted': true,
        'message': "Ce message a été supprimé",
        'type': MessageType.text.index
      });

  void _showEditDialog(MessageModel msg, String id) {
    TextEditingController ctrl = TextEditingController(text: msg.message);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier"),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  FirebaseFirestore.instance.collection('chats').doc(getChatId()).collection('messages').doc(id).update({'message': ctrl.text.trim(), 'isEdited': true});
                  Navigator.pop(context);
                }
              },
              child: const Text("OK")),
        ],
      ),
    );
  }

  // --- INTERFACE (UI) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5AB6B9),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.receiver.uid).snapshots(),
          builder: (context, userSnap) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(getChatId()).snapshots(),
              builder: (context, chatSnap) {
                bool isOnline = false;
                DateTime lastSeen = DateTime.now();
                dynamic typingStatus = "none";

                if (userSnap.hasData && userSnap.data!.exists) {
                  var data = userSnap.data!.data() as Map<String, dynamic>;
                  isOnline = data['isOnline'] ?? false;
                  lastSeen = (data['lastSeen'] is Timestamp) 
                      ? (data['lastSeen'] as Timestamp).toDate() 
                      : DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] ?? 0);
                }

                if (chatSnap.hasData && chatSnap.data!.exists) {
                  var chatData = chatSnap.data!.data() as Map<String, dynamic>;
                  typingStatus = chatData['typingStatus']?[widget.receiver.uid] ?? "none";
                }

                bool isActiveAction = typingStatus == "text" || typingStatus == "audio";

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: _getImage(widget.receiver.photoUrl, widget.receiver.name)
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.receiver.name, 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(
                            height: 16,
                            child: Text(
                              _formatStatus(isOnline, lastSeen, typingStatus), 
                              style: TextStyle(
                                fontSize: 11, 
                                color: isActiveAction ? Colors.yellowAccent : Colors.white70,
                                fontWeight: isActiveAction ? FontWeight.bold : FontWeight.normal
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage("assets/chat_bg.png"), fit: BoxFit.cover, opacity: 0.05),
        ),
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(getChatId()).collection('messages').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return !(data['hiddenFor'] ?? []).contains(currentUserId);
        }).toList();

        return ListView.builder(
          reverse: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final msg = MessageModel.fromMap(docs[index].data() as Map<String, dynamic>);
            if (!msg.isRead && msg.receiverId == currentUserId) docs[index].reference.update({'isRead': true});
            return GestureDetector(onLongPress: () => _showOptions(msg, docs[index].id), child: _buildMessageBubble(msg));
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(MessageModel msg) {
    bool isMe = msg.senderId == currentUserId;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.all(8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE1FFC7) : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.type == MessageType.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(base64Decode(msg.message), fit: BoxFit.cover),
              ),
            if (msg.type == MessageType.text)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(msg.message, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15)),
              ),
            if (msg.type == MessageType.audio)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: Color(0xFF5AB6B9), size: 32),
                    onPressed: () => _audioPlayer.play(BytesSource(base64Decode(msg.message))),
                  ),
                  const Text("Message vocal", style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.isEdited) const Text("modifié ", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                Text(DateFormat('HH:mm').format(msg.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all, size: 15, color: msg.isRead ? Colors.blue : Colors.grey),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    bool isTextEmpty = _messageController.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: _pickImage),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: _isRecording ? "Enregistrement vocal..." : "Message",
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isTextEmpty ? null : () => _sendMessage(),
            onLongPress: isTextEmpty ? _startRecording : null,
            onLongPressUp: isTextEmpty ? _stopRecording : null,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: _isRecording ? Colors.red : const Color(0xFF00A884),
              child: Icon(
                isTextEmpty ? (_isRecording ? Icons.stop : Icons.mic) : Icons.send,
                color: Colors.white,
              ),
            ),
          ),
        ],
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