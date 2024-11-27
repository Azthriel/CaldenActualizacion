import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wifi_scan/wifi_scan.dart';

//! VARIABLES !\\

//*-Colores-*\\
const Color color0 = Color(0xFFE5DACE);
const Color color1 = Color(0xFFCFC8BD);
const Color color2 = Color(0xFFBAB6AE);
const Color color3 = Color(0xFF302b36);
const Color color4 = Color(0xFF91262B);
const Color color5 = Color(0xFFE53030);
const Color color6 = Color(0xFFE77272);
//*-Colores-*\\

//*-Estado de app-*\\
const bool xProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool xReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool xDebugMode = !xProfileMode && !xReleaseMode;
//*-Estado de app-*\\

//*-Key de la app (uso de navegación y contextos)-*\\
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//*-Key de la app (uso de navegación y contextos)-*\\

//*-Relacionado al ble-*\\
MyDevice myDevice = MyDevice();
List<int> infoValues = [];
List<int> toolsValues = [];
bool bluetoothOn = true;
List<String> keywords = [];
//*-Relacionado al ble-*\\

//*-Datos del dispositivo al que te conectaste-*\\
String deviceName = '';
String softwareVersion = '';
String hardwareVersion = '';
bool connectionFlag = false;
//*-Datos del dispositivo al que te conectaste-*\\

//*-Monitoreo Localizacion y Bluetooth*-\\
Timer? locationTimer;
Timer? bluetoothTimer;
bool bleFlag = false;
//*-Monitoreo Localizacion y Bluetooth*-\\

//*-Firestore-*\\
Map<String, dynamic> fbData = {};
//*-Firestore-*\\

//*-Relacionado al wifi-*\\
List<WiFiAccessPoint> _wifiNetworksList = [];
String? _currentlySelectedSSID;
Map<String, String?> _wifiPasswordsMap = {};
FocusNode wifiPassNode = FocusNode();
bool _scanInProgress = false;
int? _expandedIndex;
bool wifiError = false;
String errorMessage = '';
String errorSintax = '';
String nameOfWifi = '';
bool isWifiConnected = false;
bool wifilogoConnected = false;
bool atemp = false;
String textState = '';
bool werror = false;
IconData wifiIcon = Icons.wifi_off;
MaterialColor statusColor = Colors.grey;
//*-Relacionado al wifi-*\\

//! FUNCIONES !\\

///*-Permite hacer prints seguros, solo en modo debug-*\\\
///Colores permitidos para [color] son:
///rojo, verde, amarillo, azul, magenta y cyan.
///
///Si no colocas ningún color se pondra por defecto...
void printLog(var text, [String? color]) {
  if (color != null) {
    switch (color.toLowerCase()) {
      case 'rojo':
        color = '\x1B[31m';
        break;
      case 'verde':
        color = '\x1B[32m';
        break;
      case 'amarillo':
        color = '\x1B[33m';
        break;
      case 'azul':
        color = '\x1B[34m';
        break;
      case 'magenta':
        color = '\x1B[35m';
        break;
      case 'cyan':
        color = '\x1B[36m';
        break;
      case 'reset':
        color = '\x1B[0m';
        break;
      default:
        color = '\x1B[0m';
        break;
    }
  } else {
    color = '\x1B[0m';
  }
  if (xDebugMode) {
    if (Platform.isAndroid) {
      // ignore: avoid_print
      print('${color}PrintData: $text\x1B[0m');
    } else {
      // ignore: avoid_print
      print("PrintData: $text");
    }
  }
}
//*-Permite hacer prints seguros, solo en modo debug-*\\

//*-Gestión de errores en app-*\\
String generateErrorReport(FlutterErrorDetails details) {
  String error =
      'Error: ${details.exception}\nStacktrace: ${details.stack}\nContexto: ${details.context}';
  return error;
}

void sendReportError(String cuerpo) async {
  printLog(cuerpo);
  String encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  String recipients = 'ingenieria@caldensmart.com';
  String subject = 'Reporte de error';

  try {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipients,
      query: encodeQueryParameters(
        <String, String>{'subject': subject, 'body': cuerpo},
      ),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
    printLog('Correo enviado');
  } catch (error) {
    printLog('Error al enviar el correo: $error');
  }
}
//*-Gestión de errores en app-*\\

//*-Funciones diversas-*\\
void showToast(String message) {
  printLog('Toast: $message');
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: color3,
    textColor: color0,
    fontSize: 16.0,
  );
}

Future<void> sendWhatsAppMessage(String phoneNumber, String message) async {
  var whatsappUrl =
      "whatsapp://send?phone=$phoneNumber&text=${Uri.encodeFull(message)}";
  Uri uri = Uri.parse(whatsappUrl);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    showToast('No se pudo abrir WhatsApp');
  }
}

void launchEmail(String mail, String asunto, String cuerpo) async {
  final Uri emailLaunchUri = Uri(
    scheme: 'mailto',
    path: mail,
    query: encodeQueryParameters(
        <String, String>{'subject': asunto, 'body': cuerpo}),
  );

  if (await canLaunchUrl(emailLaunchUri)) {
    await launchUrl(emailLaunchUri);
  } else {
    showToast('No se pudo abrir el correo electrónico');
  }
}

String encodeQueryParameters(Map<String, String> params) {
  return params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}

void launchWebURL(String url) async {
  var uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    printLog('No se pudo abrir $url');
  }
}
//*-Funciones diversas-*\\

//*-Firstore-*\\
Future<Map<String, dynamic>> fetchDocumentData() async {
  try {
    DocumentReference document =
        FirebaseFirestore.instance.collection('Calden service').doc('Equipos');

    DocumentSnapshot snapshot = await document.get();

    if (snapshot.exists) {
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      return data;
    } else {
      throw Exception("El documento no existe");
    }
  } catch (e) {
    printLog("Error al leer Firestore: $e");
    return {};
  }
}
//*-Firstore-*\\

//*-Wifi, menú y scanner-*\\
Future<void> sendWifitoBle(String ssid, String pass) async {
  MyDevice myDevice = MyDevice();
  String value = '$ssid#$pass';
  String deviceCommand = DeviceManager.getProductCode(deviceName);
  printLog(deviceCommand);
  String dataToSend = '$deviceCommand[1]($value)';
  printLog(dataToSend);
  try {
    await myDevice.toolsUuid.write(dataToSend.codeUnits);
    printLog('Se mando el wifi ANASHE');
  } catch (e) {
    printLog('Error al conectarse a Wifi $e');
  }
  ssid != 'DSC' ? atemp = true : null;
}

Future<List<WiFiAccessPoint>> _fetchWiFiNetworks() async {
  if (_scanInProgress) return _wifiNetworksList;

  _scanInProgress = true;

  try {
    if (await Permission.locationWhenInUse.request().isGranted) {
      final canScan =
          await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canScan == CanStartScan.yes) {
        final results = await WiFiScan.instance.startScan();
        if (results == true) {
          final networks = await WiFiScan.instance.getScannedResults();

          if (networks.isNotEmpty) {
            final uniqueResults = <String, WiFiAccessPoint>{};
            for (var network in networks) {
              if (network.ssid.isNotEmpty) {
                uniqueResults[network.ssid] = network;
              }
            }

            _wifiNetworksList = uniqueResults.values.toList()
              ..sort((a, b) => b.level.compareTo(a.level));
          }
        }
      } else {
        printLog('No se puede iniciar el escaneo.');
      }
    } else {
      printLog('Permiso de ubicación denegado.');
    }
  } catch (e) {
    printLog('Error durante el escaneo de WiFi: $e');
  } finally {
    _scanInProgress = false;
  }

  return _wifiNetworksList;
}

void wifiText(BuildContext context) {
  bool isAddingNetwork = false;
  String manualSSID = '';
  String manualPassword = '';

  showDialog(
    barrierDismissible: true,
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          // Función para construir la vista principal
          Widget buildMainView() {
            if (!_scanInProgress && _wifiNetworksList.isEmpty && Platform.isAndroid) {
              _fetchWiFiNetworks().then((wifiNetworks) {
                setState(() {
                  _wifiNetworksList = wifiNetworks;
                });
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xff1f1d20),
              title: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text.rich(
                      TextSpan(
                        text: 'Estado de conexión: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: isWifiConnected ? 'Conectado' : 'Desconectado',
                        style: TextStyle(
                          color: isWifiConnected ? Colors.green : Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (werror) ...[
                      Text.rich(
                        TextSpan(
                          text: 'Error: $errorMessage',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          text: 'Sintax: $errorSintax',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        const Text.rich(
                          TextSpan(
                            text: 'Red actual: ',
                            style: TextStyle(
                                fontSize: 20,
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          nameOfWifi,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ]),
                    ),
                    if (isWifiConnected) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          sendWifitoBle('DSC', 'DSC');
                          Navigator.of(context).pop();
                        },
                        style: const ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(
                            Color(0xFFFFFFFF),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Icon(Icons.signal_wifi_off),
                            Text('Desconectar Red Actual')
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (Platform.isAndroid) ...[
                      _wifiNetworksList.isEmpty && _scanInProgress
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                          : SizedBox(
                              width: double.maxFinite,
                              height: 200.0,
                              child: ListView.builder(
                                itemCount: _wifiNetworksList.length,
                                itemBuilder: (context, index) {
                                  final network = _wifiNetworksList[index];
                                  int nivel = network.level;
                                  // printLog('${network.ssid}: $nivel dBm ');
                                  return nivel >= -80
                                      ? SizedBox(
                                          child: ExpansionTile(
                                            initiallyExpanded:
                                                _expandedIndex == index,
                                            onExpansionChanged: (bool open) {
                                              if (open) {
                                                wifiPassNode.requestFocus();
                                                setState(() {
                                                  _expandedIndex = index;
                                                });
                                              } else {
                                                setState(() {
                                                  _expandedIndex = null;
                                                });
                                              }
                                            },
                                            leading: Icon(
                                              nivel >= -30
                                                  ? Icons.signal_wifi_4_bar
                                                  : // Excelente
                                                  nivel >= -67
                                                      ? Icons.signal_wifi_4_bar
                                                      : // Muy buena
                                                      nivel >= -70
                                                          ? Icons
                                                              .network_wifi_3_bar
                                                          : // Okay
                                                          nivel >= -80
                                                              ? Icons
                                                                  .network_wifi_2_bar
                                                              : // No buena
                                                              Icons
                                                                  .signal_wifi_off, // Inusable
                                              color: Colors.white,
                                            ),
                                            title: Text(
                                              network.ssid,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                            backgroundColor:
                                                const Color(0xff1f1d20),
                                            collapsedBackgroundColor:
                                                const Color(0xff1f1d20),
                                            textColor: Colors.white,
                                            iconColor: Colors.white,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 8.0),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.lock,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8.0),
                                                    Expanded(
                                                      child: TextField(
                                                        focusNode: wifiPassNode,
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFFFFFFFF),
                                                        ),
                                                        decoration:
                                                            const InputDecoration(
                                                          hintText:
                                                              'Escribir contraseña',
                                                          hintStyle: TextStyle(
                                                            color: Colors.grey,
                                                          ),
                                                          enabledBorder:
                                                              UnderlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .white),
                                                          ),
                                                          focusedBorder:
                                                              UnderlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .blue),
                                                          ),
                                                          border:
                                                              UnderlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .white),
                                                          ),
                                                        ),
                                                        obscureText: true,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            _currentlySelectedSSID =
                                                                network.ssid;
                                                            _wifiPasswordsMap[
                                                                    network
                                                                        .ssid] =
                                                                value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                },
                              ),
                            ),
                    ] else ...[
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Campo para SSID
                            Row(
                              children: [
                                const Icon(
                                  Icons.wifi,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: TextField(
                                    cursorColor: Colors.white,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Agregar WiFi',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      manualSSID = value;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: TextField(
                                    cursorColor: Colors.white,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Contraseña',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                    ),
                                    obscureText: true,
                                    onChanged: (value) {
                                      manualPassword = value;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code,
                        color: Color(0xFFFFFFFF),
                      ),
                      iconSize: 30,
                      onPressed: () async {
                        PermissionStatus permissionStatusC =
                            await Permission.camera.request();
                        if (!permissionStatusC.isGranted) {
                          await Permission.camera.request();
                        }
                        permissionStatusC = await Permission.camera.status;
                        if (permissionStatusC.isGranted) {
                          openQRScanner(navigatorKey.currentContext ?? context);
                        }
                      },
                    ),
                    Platform.isAndroid
                        ? TextButton(
                            style: const ButtonStyle(),
                            child: const Text(
                              'Agregar Red',
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                isAddingNetwork = true;
                              });
                            },
                          )
                        : const SizedBox.shrink(),
                    TextButton(
                      style: const ButtonStyle(),
                      child: const Text(
                        'Conectar',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      onPressed: () {
                        if (_currentlySelectedSSID != null &&
                            _wifiPasswordsMap[_currentlySelectedSSID] != null) {
                          printLog(
                              '$_currentlySelectedSSID#${_wifiPasswordsMap[_currentlySelectedSSID]}');
                          sendWifitoBle(_currentlySelectedSSID!,
                              _wifiPasswordsMap[_currentlySelectedSSID]!);
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          }

          Widget buildAddNetworkView() {
            return AlertDialog(
              backgroundColor: const Color(0xff1f1d20),
              title: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFFFFFFF),
                    ),
                    onPressed: () {
                      setState(() {
                        isAddingNetwork = false;
                      });
                    },
                  ),
                  const Text(
                    'Agregar red\nmanualmente',
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Campo para SSID
                    Row(
                      children: [
                        const Icon(
                          Icons.wifi,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: TextField(
                            cursorColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Agregar WiFi',
                              hintStyle: TextStyle(color: Colors.grey),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            onChanged: (value) {
                              manualSSID = value;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.lock,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: TextField(
                            cursorColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Contraseña',
                              hintStyle: TextStyle(color: Colors.grey),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            obscureText: true,
                            onChanged: (value) {
                              manualPassword = value;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (manualSSID.isNotEmpty && manualPassword.isNotEmpty) {
                      printLog('$manualSSID#$manualPassword');

                      sendWifitoBle(manualSSID, manualPassword);
                      Navigator.of(context).pop();
                    } else {}
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                      const Color(0xff1f1d20),
                    ),
                  ),
                  child: const Text(
                    'Agregar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          }

          return isAddingNetwork
              ? buildAddNetworkView()
              : buildMainView(); // Mostrar la vista correspondiente
        },
      );
    },
  ).then((_) {
    _scanInProgress = false;
    _expandedIndex = null;
  });
}

String getWifiErrorSintax(int errorCode) {
  switch (errorCode) {
    case 1:
      return "WIFI_REASON_UNSPECIFIED";
    case 2:
      return "WIFI_REASON_AUTH_EXPIRE";
    case 3:
      return "WIFI_REASON_AUTH_LEAVE";
    case 4:
      return "WIFI_REASON_ASSOC_EXPIRE";
    case 5:
      return "WIFI_REASON_ASSOC_TOOMANY";
    case 6:
      return "WIFI_REASON_NOT_AUTHED";
    case 7:
      return "WIFI_REASON_NOT_ASSOCED";
    case 8:
      return "WIFI_REASON_ASSOC_LEAVE";
    case 9:
      return "WIFI_REASON_ASSOC_NOT_AUTHED";
    case 10:
      return "WIFI_REASON_DISASSOC_PWRCAP_BAD";
    case 11:
      return "WIFI_REASON_DISASSOC_SUPCHAN_BAD";
    case 12:
      return "WIFI_REASON_BSS_TRANSITION_DISASSOC";
    case 13:
      return "WIFI_REASON_IE_INVALID";
    case 14:
      return "WIFI_REASON_MIC_FAILURE";
    case 15:
      return "WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT";
    case 16:
      return "WIFI_REASON_GROUP_KEY_UPDATE_TIMEOUT";
    case 17:
      return "WIFI_REASON_IE_IN_4WAY_DIFFERS";
    case 18:
      return "WIFI_REASON_GROUP_CIPHER_INVALID";
    case 19:
      return "WIFI_REASON_PAIRWISE_CIPHER_INVALID";
    case 20:
      return "WIFI_REASON_AKMP_INVALID";
    case 21:
      return "WIFI_REASON_UNSUPP_RSN_IE_VERSION";
    case 22:
      return "WIFI_REASON_INVALID_RSN_IE_CAP";
    case 23:
      return "WIFI_REASON_802_1X_AUTH_FAILED";
    case 24:
      return "WIFI_REASON_CIPHER_SUITE_REJECTED";
    case 25:
      return "WIFI_REASON_TDLS_PEER_UNREACHABLE";
    case 26:
      return "WIFI_REASON_TDLS_UNSPECIFIED";
    case 27:
      return "WIFI_REASON_SSP_REQUESTED_DISASSOC";
    case 28:
      return "WIFI_REASON_NO_SSP_ROAMING_AGREEMENT";
    case 29:
      return "WIFI_REASON_BAD_CIPHER_OR_AKM";
    case 30:
      return "WIFI_REASON_NOT_AUTHORIZED_THIS_LOCATION";
    case 31:
      return "WIFI_REASON_SERVICE_CHANGE_PERCLUDES_TS";
    case 32:
      return "WIFI_REASON_UNSPECIFIED_QOS";
    case 33:
      return "WIFI_REASON_NOT_ENOUGH_BANDWIDTH";
    case 34:
      return "WIFI_REASON_MISSING_ACKS";
    case 35:
      return "WIFI_REASON_EXCEEDED_TXOP";
    case 36:
      return "WIFI_REASON_STA_LEAVING";
    case 37:
      return "WIFI_REASON_END_BA";
    case 38:
      return "WIFI_REASON_UNKNOWN_BA";
    case 39:
      return "WIFI_REASON_TIMEOUT";
    case 46:
      return "WIFI_REASON_PEER_INITIATED";
    case 47:
      return "WIFI_REASON_AP_INITIATED";
    case 48:
      return "WIFI_REASON_INVALID_FT_ACTION_FRAME_COUNT";
    case 49:
      return "WIFI_REASON_INVALID_PMKID";
    case 50:
      return "WIFI_REASON_INVALID_MDE";
    case 51:
      return "WIFI_REASON_INVALID_FTE";
    case 67:
      return "WIFI_REASON_TRANSMISSION_LINK_ESTABLISH_FAILED";
    case 68:
      return "WIFI_REASON_ALTERATIVE_CHANNEL_OCCUPIED";
    case 200:
      return "WIFI_REASON_BEACON_TIMEOUT";
    case 201:
      return "WIFI_REASON_NO_AP_FOUND";
    case 202:
      return "WIFI_REASON_AUTH_FAIL";
    case 203:
      return "WIFI_REASON_ASSOC_FAIL";
    case 204:
      return "WIFI_REASON_HANDSHAKE_TIMEOUT";
    case 205:
      return "WIFI_REASON_CONNECTION_FAIL";
    case 206:
      return "WIFI_REASON_AP_TSF_RESET";
    case 207:
      return "WIFI_REASON_ROAMING";
    default:
      return "Error Desconocido";
  }
}
//*-Wifi, menú y scanner-*\\

//*-Qr scanner-*\\
Future<void> openQRScanner(BuildContext context) async {
  try {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var qrResult = await navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (context) => const QRScanPage()));
      if (qrResult != null) {
        var wifiData = parseWifiQR(qrResult);
        sendWifitoBle(wifiData['SSID']!, wifiData['password']!);
      }
    });
  } catch (e) {
    printLog("Error during navigation: $e");
  }
}

Map<String, String> parseWifiQR(String qrContent) {
  printLog(qrContent);
  final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(qrContent);
  final passwordMatch = RegExp(r'P:([^;]+)').firstMatch(qrContent);

  final ssid = ssidMatch?.group(1) ?? '';
  final password = passwordMatch?.group(1) ?? '';
  return {"SSID": ssid, "password": password};
}
//*-Qr scanner-*\\

//! CLASES !\\

//*- Funciones relacionadas a los equipos*-\\
class DeviceManager {
  ///Extrae el número de serie desde el deviceName
  static String extractSerialNumber(String productName) {
    RegExp regExp = RegExp(r'(\d{8})');

    Match? match = regExp.firstMatch(productName);

    return match?.group(0) ?? '';
  }

  ///Conseguir el código de producto en base al deviceName
  static String getProductCode(String device) {
    Map<String, String> data = (fbData['PC'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        value.toString(),
      ),
    );
    String cmd = '';
    for (String key in data.keys) {
      if (device.contains(key)) {
        cmd = data[key].toString();
      }
    }
    return cmd;
  }
}
//*- Funciones relacionadas a los equipos*-\\

//*-BLE, configuraciones del equipo-*\\
class MyDevice {
  static final MyDevice _singleton = MyDevice._internal();

  factory MyDevice() {
    return _singleton;
  }

  MyDevice._internal();

  late BluetoothDevice device;
  late BluetoothCharacteristic infoUuid;
  late BluetoothCharacteristic toolsUuid;
  late BluetoothCharacteristic otaUuid;

  Future<bool> setup(BluetoothDevice connectedDevice) async {
    try {
      device = connectedDevice;

      Map<String, String> servicios =
          (fbData['services'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          value.toString(),
        ),
      );

      Map<String, String> charac =
          (fbData['chars'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          value.toString(),
        ),
      );

      List<BluetoothService> services =
          await device.discoverServices(timeout: 3);
      // printLog('Los servicios: $services');

      BluetoothService infoService = services.firstWhere(
        (s) => s.uuid == Guid(servicios['info']!),
      );
      infoUuid = infoService.characteristics.firstWhere(
        (c) => c.uuid == Guid(charac['info']!),
      ); //ProductType:SerialNumber:SoftVer:HardVer:Owner
      toolsUuid = infoService.characteristics.firstWhere(
        (c) => c.uuid == Guid(charac['tools']!),
      ); //WifiStatus:WifiSSID/WifiError:BleStatus(users)

      infoValues = await infoUuid.read();
      String str = utf8.decode(infoValues);
      var partes = str.split(':');
      softwareVersion = partes[2];
      hardwareVersion = partes[3];
      printLog(
          'Product code: ${DeviceManager.getProductCode(device.platformName)}');
      printLog(
          'Serial number: ${DeviceManager.extractSerialNumber(device.platformName)}');

      BluetoothService espService = services.firstWhere(
        (s) =>
            s.uuid ==
            Guid(
              DeviceManager.getProductCode(device.platformName) == '015773_IOT'
                  ? servicios['Esp57']!
                  : servicios['espService']!,
            ),
      );

      otaUuid = espService.characteristics.firstWhere(
        (c) => c.uuid == Guid(charac['ota']!),
      );

      return Future.value(true);
    } catch (e, stackTrace) {
      printLog('Lcdtmbe $e $stackTrace');

      return Future.value(false);
    }
  }
}
//*-BLE, configuraciones del equipo-*\\

//*-Metodos, interacción con código Nativo-*\\
class NativeService {
  static const platform = MethodChannel('com.calden.service/native');

  static Future<bool> isLocationServiceEnabled() async {
    try {
      final bool isEnabled =
          await platform.invokeMethod("isLocationServiceEnabled");
      return isEnabled;
    } on PlatformException catch (e) {
      printLog('Error verificando ubicación: $e');
      return false;
    }
  }

  static Future<void> isBluetoothServiceEnabled() async {
    try {
      final bool isBluetoothOn = await platform.invokeMethod('isBluetoothOn');

      if (!isBluetoothOn && !bleFlag) {
        bleFlag = true;
        final bool turnedOn = await platform.invokeMethod('turnOnBluetooth');

        if (turnedOn) {
          bleFlag = false;
        } else {
          printLog("El usuario rechazó encender Bluetooth");
        }
      }
    } on PlatformException catch (e) {
      printLog("Error al verificar o encender Bluetooth: ${e.message}");

      bleFlag = false;
    }
  }

  static Future<void> openLocationOptions() async {
    try {
      await platform.invokeMethod("openLocationSettings");
    } on PlatformException catch (e) {
      printLog('Error abriendo la configuración de ubicación: $e');
    }
  }
}
//*-Metodos, interacción con código Nativo-*\\

//*-QR Scan, lee datos de qr wifi-*\\
class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});
  @override
  QRScanPageState createState() => QRScanPageState();
}

class QRScanPageState extends State<QRScanPage>
    with SingleTickerProviderStateMixin {
  Barcode? result;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  MobileScannerController controller = MobileScannerController();
  AnimationController? animationController;
  bool flashOn = false;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    animation = Tween<double>(begin: 10, end: 350).animate(animationController!)
      ..addListener(() {
        setState(() {});
      });

    animationController!.repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        MobileScanner(
          controller: controller,
          onDetect: (
            barcode,
          ) {
            setState(() {
              result = barcode.barcodes.first;
            });
            if (result != null) {
              Navigator.pop(context, result!.rawValue);
            }
          },
        ),
        // Arriba
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 250,
          child: Container(
              color: Colors.black54,
              child: const Center(
                child: Text(
                  'Escanea el QR',
                  style: TextStyle(
                    color: Color(0xFFB2B5AE),
                  ),
                ),
              )),
        ),
        // Abajo
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 250,
          child: Container(
            color: Colors.black54,
          ),
        ),
        // Izquierda
        Positioned(
          top: 250,
          bottom: 250,
          left: 0,
          width: 50,
          child: Container(
            color: Colors.black54,
          ),
        ),
        // Derecha
        Positioned(
          top: 250,
          bottom: 250,
          right: 0,
          width: 50,
          child: Container(
            color: Colors.black54,
          ),
        ),
        // Área transparente con bordes redondeados
        Positioned(
          top: 250,
          left: 50,
          right: 50,
          bottom: 250,
          child: Stack(
            children: [
              Positioned(
                top: animation.value,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  color: const Color(0xFF1E242B),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  color: const Color(0xFFB2B5AE),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  color: const Color(0xFFB2B5AE),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: Container(
                  width: 3,
                  color: const Color(0xFFB2B5AE),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Container(
                  width: 3,
                  color: const Color(0xFFB2B5AE),
                ),
              ),
            ],
          ),
        ),
        // Botón de Flash
        Positioned(
          bottom: 20,
          right: 20,
          child: IconButton(
            icon: Icon(
                controller.torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () => controller.toggleTorch(),
          ),
        ),
      ]),
    );
  }
}
//*-QR Scan, lee datos de qr wifi-*\\