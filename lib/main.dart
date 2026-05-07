/*import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart' as my_auth;
import 'providers/theme_provider.dart';
import 'views/login_page.dart';
import 'views/users_page.dart';

// --- CONFIGURATION NOTIFICATIONS ---

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'chat_messages', 
  'Chat Messages',
  description: 'Ce canal est utilisé pour les notifications importantes.',
  importance: Importance.max,
  playSound: true,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// --- MAIN ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Configuration pour afficher les notifications même quand l'app est ouverte
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => my_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// --- APPLICATION PRINCIPALE ---

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  void _setupFCM() async {
    // Initialisation des notifications locales
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);


    // Écouter les messages au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: android.smallIcon,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // Routes sécurisées (SANS CONST ICI)
      initialRoute: '/',
      routes: {
        '/': (context) => AppLifecycleManager(child: const AuthWrapper()),
        '/login': (context) => LoginScreen(), 
        '/users': (context) => const UsersPage(),
      },
    );
  }
}

// --- GESTION DU STATUT EN LIGNE ---

class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updateStatus(state == AppLifecycleState.resumed);
  }

  void _updateStatus(bool isOnline) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      }).catchError((e) => print("Erreur status: $e"));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// --- GESTION DE L'AUTHENTIFICATION ---

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const UsersPage();
        }
        return LoginScreen();
      },
    );
  }
}*/




import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart' as my_auth;
import 'providers/theme_provider.dart';
import 'views/login_page.dart';
import 'views/users_page.dart';

// --- CONFIGURATION NOTIFICATIONS ---

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'chat_messages', 
  'Chat Messages',
  description: 'Ce canal est utilisé pour les notifications importantes.',
  importance: Importance.max,
  playSound: true,
);

// Handler pour les messages reçus quand l'application est totalement fermée (Background/Terminated)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Enregistrement du background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Création du canal pour Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Configuration de l'affichage des notifications au premier plan (Foreground)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => my_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  // Configuration de Firebase Cloud Messaging
  void _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. DEMANDE DE PERMISSION (Essentiel pour Android 13+ et iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permission de notification accordée');
      
      // 2. RÉCUPÉRATION ET SAUVEGARDE DU TOKEN
      _saveDeviceToken();
    }

    // 3. INITIALISATION DES NOTIFICATIONS LOCALES
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // 4. ÉCOUTE DES MESSAGES AU PREMIER PLAN (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null) { // Retirez la condition 'android != null' pour plus de souplesse
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, // 'chat_messages'
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher', // Utilisez l'icône par défaut
          // AJOUTEZ CETTE LIGNE :
          ticker: 'ticker',
        ),
      ),
    );
  }
});
  }

  // Fonction pour sauvegarder le token dans le profil de l'utilisateur
  void _saveDeviceToken() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        print("🚀 FCM Token sauvegardé : $token");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => AppLifecycleManager(child: const AuthWrapper()),
        '/login': (context) => LoginScreen(), 
        '/users': (context) => const UsersPage(),
      },
    );
  }
}

// --- GESTION DU STATUT EN LIGNE ---

class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updateStatus(state == AppLifecycleState.resumed);
    // On rafraîchit le token à chaque retour sur l'app pour être sûr
    if (state == AppLifecycleState.resumed) {
      _updateTokenOnResume();
    }
  }

  void _updateTokenOnResume() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        FirebaseFirestore.instance.collection('users').doc(uid).update({'fcmToken': token});
      }
    }
  }

  void _updateStatus(bool isOnline) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      }).catchError((e) => print("🚨 Erreur status: $e"));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// --- GESTION DE L'AUTHENTIFICATION ---

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const UsersPage();
        }
        return LoginScreen();
      },
    );
  }
}