/*import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';

class GroupChatPage extends StatefulWidget {
  final GroupModel group;
  const GroupChatPage({super.key, required this.group});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- LOGIQUE D'ENVOI ---
  void _sendMessage({String? content, MessageType type = MessageType.text}) async {
    String messageContent = content ?? _messageController.text.trim();
    if (messageContent.isEmpty && type == MessageType.text) return;

    final msgData = {
      'senderId': currentUserId,
      'message': messageContent,
      'type': type.index,
      'timestamp': FieldValue.serverTimestamp(),
      'isEdited': false,
      'isDeleted': false,
      'hiddenFor': [],
    };

    if (type == MessageType.text) _messageController.clear();

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.group.groupId)
        .collection('messages')
        .add(msgData);
    
    FirebaseFirestore.instance.collection('groups').doc(widget.group.groupId).update({
      'lastMessage': type == MessageType.image ? "📷 Image" : (type == MessageType.audio ? "🎤 Audio" : messageContent),
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  // (Méthodes Multimédia identiques)
  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (file != null) {
      final bytes = await file.readAsBytes();
      _sendMessage(content: base64Encode(bytes), type: MessageType.image);
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/group_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      final bytes = await File(path).readAsBytes();
      _sendMessage(content: base64Encode(bytes), type: MessageType.audio);
    }
  }

  // --- ACTIONS MESSAGES ---
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
                leading: const Icon(Icons.edit, color: Color(0xFF5AB6B9)),
                title: const Text("Modifier"),
                onTap: () { Navigator.pop(context); _showEditDialog(msg, messageId); },
              ),
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.orange),
              title: const Text("Supprimer pour moi"),
              onTap: () { Navigator.pop(context); _deleteForMe(messageId); },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Supprimer pour tous"),
                onTap: () { Navigator.pop(context); _deleteForEveryone(messageId); },
              ),
          ],
        ),
      ),
    );
  }

  void _deleteForMe(String id) => FirebaseFirestore.instance.collection('groups').doc(widget.group.groupId).collection('messages').doc(id).update({'hiddenFor': FieldValue.arrayUnion([currentUserId])});
  void _deleteForEveryone(String id) => FirebaseFirestore.instance.collection('groups').doc(widget.group.groupId).collection('messages').doc(id).update({'isDeleted': true, 'message': "Message supprimé"});

  void _showEditDialog(MessageModel msg, String id) {
    final ctrl = TextEditingController(text: msg.message);
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Modifier"),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        ElevatedButton(onPressed: () {
          FirebaseFirestore.instance.collection('groups').doc(widget.group.groupId).collection('messages').doc(id).update({'message': ctrl.text.trim(), 'isEdited': true});
          Navigator.pop(context);
        }, child: const Text("OK")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF5AB6B9),
              child: Icon(Icons.group, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.group.groupName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .where('uid', whereIn: widget.group.members)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Text("Chargement...", style: TextStyle(fontSize: 10));
                      List<String> names = snapshot.data!.docs.map((doc) => doc['name'] as String).toList();
                      return Text(
                        names.join(", "),
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups').doc(widget.group.groupId).collection('messages')
          .orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          List hiddenList = data['hiddenFor'] ?? [];
          return !hiddenList.contains(currentUserId);
        }).toList();

        return ListView.builder(
          reverse: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> data = docs[index].data() as Map<String, dynamic>;
            
            // --- SÉCURISATION DU TIMESTAMP ---
            // Si le timestamp est null (pendant l'envoi), on injecte l'heure actuelle
            // pour éviter que le modèle MessageModel.fromMap ne crash.
            if (data['timestamp'] == null) {
              data['timestamp'] = Timestamp.now();
            }

            final msg = MessageModel.fromMap(data);

            return GestureDetector(
              onLongPress: () => _showOptions(msg, docs[index].id),
              child: _buildMessageBubble(msg),
            );
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
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF5AB6B9) : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.type == MessageType.text)
              Text(msg.message, style: TextStyle(color: isMe || isDark ? Colors.white : Colors.black)),
            if (msg.type == MessageType.image)
               ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(msg.message), width: 220)),
            if (msg.type == MessageType.audio)
              IconButton(
                icon: Icon(Icons.play_circle_fill, size: 30, color: isMe ? Colors.white : const Color(0xFF5AB6B9)),
                onPressed: () => _audioPlayer.play(BytesSource(base64Decode(msg.message))),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.isEdited) Text("modifié ", style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
                Text(
                  DateFormat('HH:mm').format(msg.timestamp),
                  style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.image, color: Color(0xFF5AB6B9)), onPressed: _pickImage),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _isRecording ? "Enregistrement..." : "Message de groupe",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressUp: _stopRecording,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _isRecording ? Colors.red : const Color(0xFF5AB6B9),
              child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 5),
          IconButton(
            icon: const Icon(Icons.send),
            color: _messageController.text.trim().isEmpty ? Colors.grey : const Color(0xFF5AB6B9),
            onPressed: _messageController.text.trim().isEmpty ? null : () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}*/

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
import '../models/group_model.dart';
import '../models/message_model.dart';

class GroupChatPage extends StatefulWidget {
  final GroupModel group;
  const GroupChatPage({super.key, required this.group});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Couleur personnalisée demandée
  final Color customGreen = const Color(0xFF5AB6B9);
  
  bool _isRecording = false;
  Timer? _typingTimer;
  Map<String, String> memberNames = {}; 

  @override
  void initState() {
    super.initState();
    _loadMemberNames();
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

  // --- LOGIQUE DE DONNÉES ---

  Future<void> _loadMemberNames() async {
    final snapshots = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', whereIn: widget.group.members)
        .get();
    for (var doc in snapshots.docs) {
      memberNames[doc.id] = doc['name'];
    }
    if (mounted) setState(() {});
  }

  String _getMembersString() {
    List<String> names = [];
    for (var uid in widget.group.members) {
      if (uid == currentUserId) {
        names.add("Vous");
      } else if (memberNames.containsKey(uid)) {
        names.add(memberNames[uid]!);
      }
    }
    return names.join(", ");
  }

  void _setTypingStatus(String status) {
    FirebaseFirestore.instance.collection('groups').doc(widget.group.groupId).set({
      'typingStatus': {currentUserId: status}
    }, SetOptions(merge: true));
  }

  void _onTextChanged(String value) {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _setTypingStatus("text");
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTypingStatus("none");
    });
  }

  // --- OPTIONS AVANCÉES (MODIFIER / SUPPRIMER) ---

  void _showMessageOptions(String messageId, MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isMe && msg.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text("Modifier"),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(messageId, msg.message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.orange),
                title: const Text("Supprimer pour moi"),
                onTap: () {
                  FirebaseFirestore.instance
                      .collection('groups').doc(widget.group.groupId)
                      .collection('messages').doc(messageId)
                      .update({'hiddenFor': FieldValue.arrayUnion([currentUserId])});
                  Navigator.pop(context);
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text("Supprimer pour tous"),
                  onTap: () {
                    FirebaseFirestore.instance
                        .collection('groups').doc(widget.group.groupId)
                        .collection('messages').doc(messageId)
                        .delete();
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(String messageId, String currentText) {
    final TextEditingController editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifier le message"),
        content: TextField(controller: editController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('groups').doc(widget.group.groupId)
                    .collection('messages').doc(messageId)
                    .update({
                  'message': editController.text.trim(),
                  'isEdited': true,
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  // --- ENVOI ET MULTIMÉDIA ---

  void _sendMessage({String? content, MessageType type = MessageType.text}) async {
    String messageContent = content ?? _messageController.text.trim();
    if (messageContent.isEmpty && type == MessageType.text) return;

    _setTypingStatus("none");
    final msgData = {
      'senderId': currentUserId,
      'message': messageContent,
      'type': type.index,
      'timestamp': FieldValue.serverTimestamp(),
      'isEdited': false,
      'isDeleted': false,
      'hiddenFor': [],
    };

    if (type == MessageType.text) _messageController.clear();
    await FirebaseFirestore.instance.collection('groups').doc(widget.group.groupId).collection('messages').add(msgData);
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (file != null) {
      final bytes = await file.readAsBytes();
      _sendMessage(content: base64Encode(bytes), type: MessageType.image);
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      _setTypingStatus("audio");
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/group_${DateTime.now().millisecondsSinceEpoch}.m4a';
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

  // --- INTERFACE (UI) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('groups').doc(widget.group.groupId).snapshots(),
          builder: (context, snapshot) {
            String subTitle = _getMembersString();
            Color statusColor = Colors.grey;

            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              var typingMap = data['typingStatus'] as Map<String, dynamic>? ?? {};
              
              typingMap.forEach((uid, status) {
                if (uid != currentUserId && status != "none") {
                  String name = memberNames[uid] ?? "Quelqu'un";
                  subTitle = status == "text" ? "$name écrit..." : "$name enregistre un vocal...";
                  statusColor = customGreen;
                }
              });
            }

            return Row(
              children: [
                CircleAvatar(
                  backgroundColor: customGreen,
                  child: const Icon(Icons.group, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.group.groupName, 
                        style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(
                        height: 16,
                        child: Text(
                          subTitle, 
                          style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups').doc(widget.group.groupId).collection('messages')
          .orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs.where((d) {
          List hiddenFor = d['hiddenFor'] ?? [];
          return !hiddenFor.contains(currentUserId);
        }).toList();

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            if (data['timestamp'] == null) data['timestamp'] = Timestamp.now();
            final msg = MessageModel.fromMap(data);
            bool isMe = msg.senderId == currentUserId;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe) _buildAvatar(msg.senderId), 
                  const SizedBox(width: 8),
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(doc.id, msg, isMe),
                    child: _buildBubble(msg, isMe),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircleAvatar(radius: 16, backgroundColor: Colors.grey);
        var url = snap.data!['photoUrl'] ?? "";
        return CircleAvatar(
          radius: 16,
          backgroundImage: url.startsWith('http') 
            ? NetworkImage(url) 
            : MemoryImage(base64Decode(url)) as ImageProvider,
        );
      },
    );
  }

  Widget _buildBubble(MessageModel msg, bool isMe) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? customGreen : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15),
          topRight: const Radius.circular(15),
          bottomLeft: Radius.circular(isMe ? 15 : 0),
          bottomRight: Radius.circular(isMe ? 0 : 15),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) 
            Text(
              memberNames[msg.senderId] ?? "Membre",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: customGreen),
            ),
          const SizedBox(height: 4),
          if (msg.type == MessageType.text)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(msg.message, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
                ),
                if (msg.isEdited == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Text(
                      "(modifié)",
                      style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          if (msg.type == MessageType.image)
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(msg.message))),
          if (msg.type == MessageType.audio)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.play_circle_fill, color: isMe ? Colors.white : customGreen, size: 30),
                  onPressed: () => _audioPlayer.play(BytesSource(base64Decode(msg.message))),
                ),
                Text("Audio vocal", style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.grey)),
              ],
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              DateFormat('HH:mm').format(msg.timestamp),
              style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_a_photo, color: Colors.grey), onPressed: _pickImage),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(25)),
              child: TextField(
                controller: _messageController,
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: _isRecording ? "Enregistrement..." : "Écrivez votre message...",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressUp: _stopRecording,
            child: CircleAvatar(
              backgroundColor: _isRecording ? Colors.red : customGreen,
              child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white),
            ),
          ),
          const SizedBox(width: 5),
          IconButton(
            icon: Icon(Icons.send, color: customGreen),
            onPressed: () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}