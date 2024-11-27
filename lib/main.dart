import 'package:caldenservice/device.dart';
import 'package:caldenservice/firebase_options.dart';
import 'package:caldenservice/loading.dart';
import 'package:caldenservice/master.dart';
import 'package:caldenservice/permission.dart';
import 'package:caldenservice/scan.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (FlutterErrorDetails details) async {
    String errorReport = generateErrorReport(details);
    sendReportError(errorReport);
  };

  printLog('Todo configurado, iniciando app');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      fbData = await fetchDocumentData();
      printLog(fbData, "rojo");
    });
    printLog('Empezamos');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Caldén Service',
      theme: ThemeData(
        primaryColor: const Color(0xFF302b36),
        primaryColorLight: const Color(0xFFCFC8BD),
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Color(0xFFCFC8BD),
          selectionHandleColor: Color(0xFFCFC8BD),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF302b36),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/perm',
      routes: {
        '/perm': (context) => const PermissionHandler(),
        '/scan': (context) => const ScanPage(),
        '/loading': (context) => const LoadingPage(),
        '/device': (context) => const DevicePage(),
      },
    );
  }
}
