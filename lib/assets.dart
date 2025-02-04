import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:boxicons/boxicons.dart';
import 'package:just_audio/just_audio.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:elegant_notification/elegant_notification.dart';
import 'package:js/js.dart';

@JS()external void sfInvokeDialerJS(String direction, String phoneNumber, Function callback);
@JS()external void sfToggleSoftphonePanelJS(bool hidden); 
@JS()external void sfRunApexGetUserDetailJS(Function callback);
@JS()external void startCallListener(Function callback);
@JS()external void sfSearchRecordJS(String callerNumber, String searchDefaultOrder, String defaultPopupFormAPIName);
@JS()external void sfNavigateRecord(String navigatePage, String callerNumber);

getSfUserDetail() {
  final completer = Completer<dynamic>();

  sfRunApexGetUserDetailJS(allowInterop((result) {
    completer.complete(result);
  }));

  return completer.future;
}

sfInvokeDialer(String number, String phoneNumber) {
  final completer = Completer<dynamic>();

  sfInvokeDialerJS(number, phoneNumber, allowInterop((result) {
    completer.complete(result);
  }));

  return completer.future;
}

class CallListener {
  static final StreamController<String> _callStreamController = StreamController.broadcast();

  static Stream<String> get onNewCall => _callStreamController.stream;

  static void initialize() {
    startCallListener(allowInterop((String phoneNumber) {
      _callStreamController.add(phoneNumber);
    }));
  }
}

Call? callDirections;
bool inProgress = false;
bool dialerStatus = false;
bool debug = false;
bool initial = true;
bool dialOpen = true;
bool activeCall = false;
bool supervisor = false;
bool enableAuxcodes = false;
bool visibleSoftphone = false;
HtmlUnescape unescape = HtmlUnescape();

const Color primaryColor = Color(0xFF1E274a);
const Color primaryColor2 = Color(0xFF1B9DD9);
const Color secondaryColor = Color(0xFFB7BFEE);
const Color secondaryColor2 = Color(0xFFD9D9D9);
const Color backgroundColor = Color(0xFF101A38);
const Color backgroundColor2 = Color(0xFFEEF0FB);
const Color backgroundColor3 = Color(0xFFDED0E4);
const Color blueColor = Colors.blue;
const Color blueColor2 = Colors.blueAccent;
const Color cusorColor = Colors.white;
const Color greenColor = Color(0xFF008080);
const Color greenColor2 = Color(0xFF00FF38);
const Color greyColor = Color(0xFFD9D9D9);
Color greyColor2 = Colors.grey.shade600;
const Color greyColor3 = Color(0xFF686A8A);
const Color orangeColor = Color(0xFFF9A825);
const Color redColor = Colors.redAccent;
const Color redColor2 = Color(0xFFC62828);
const Color appbarColor = Colors.white;
const Color whiteColor = Color(0xFFFAFAFA);
const Color iconColor = Colors.black;
Color iconColor2 = Colors.grey.shade900;
Color iconColor3 = Colors.grey.shade800;
const Color purpleColor = Color(0xFF502DC7);
const Color textColor = Color(0xFF101A38);
const Color textColor2 = Color(0xFF525E79);
const Color headerColor = Color(0xFF212529);
Color statusColor = greyColor;

double width = 0;
double height = 0;
double headerSize = 16.0;
double paragraphSize = 14.0;
double subParagraphSize = 9.0;
int supervisorMode = 0;
int chameleonMode = 0;

io.Socket? socket; 
enum Direction { incoming, outgoing }

final beepPlayer = AudioPlayer();

void playBeepSound() async {
  await beepPlayer.setAsset("sounds/beep.wav");
  await beepPlayer.setVolume(0.03);
  await beepPlayer.play();
}

String ringqServer = '';
String username = ''; 
String password = ''; 
String extentionNo = ''; 
String destination = '';
String destinationName = '';
String prioritySfSearchOrder = '';
String prioritySfForm = '';
String supervisorCall = '';
String versionNumber = '';
String sessionCookie1 = '';
String sessionCookie2 = '';
String sessionCookie3 = '';
String queueWaitingTime = '';
String primaryOutbound = '';
String url = "https://$ringqServer:8443";
String socketUrl = debug ? '' : "$ringqServer:9443";
String sipSocketUrl = debug ? '' : "$ringqServer:7443";
String sipUrl = debug ? '' : "${session['extension']}@${session["subdomain"]}:7443";
String balance = '';
String agentStatus = '';
String activeProfileStatus = "Available";
String pinBasedDailing = "1"; 

Map session = {};
Map callProfiles = {};
Map queueScripts = {};
Map teamAvatars = {};
Map accountBalance = {};
Map timeschedules = {};
Map walldata = {"active": 0, "waiting": 0, "abandoned": 0, "total": 0};
Map wallinfo = {"agents": 0, "contacts": 0, "voicemails": 0};
Map wallStatus = {};

List auxcodes = [];
List agents = [];
List agents2 = [];
List agents3 = [];
List devices = [];
List devices2 = [];
List dids = [];
List holidays = [];
List holidays2 = [];
List extensions = [];
List ivrs = [];
List ivrs2 = [];
List ivrs3 = [];
List ivrs4 = [];
List queues = [];
List queues2 = [];
List queues3 = [];
List queues4 = [];
List queueConfig = [];
List scripts = [];
List recordings = [];
List recordings2 = [];
List queueCalls = [];
List voicemails = [];
List agentCalls = [];
List agent2Calls = [];
List conferences = [];
List faxes = [];
List parkedSlots = ["", "", "", "", ""];
List queueDetails = [];
List abadonedCalls = [];
List availableDids = [];
List activeProfiles = [];
List activeProfileColors = [];

Color activeProfileColor = greenColor2;

final List<String> callStrategies = [
  "Essential",
  "Ring All",
  "Random",
  "Pro",
  "Longest Waiting Time",
  "Round Robin",
  "Least Talk Time",
  "Fewest Answered",
  "Top~Down",
  "Pro+",
  "Skill Based Ring All",
  "Skill Based Random",
  "Skill Based Round Robin",
  "Skill Based Fewest Answered",
  "Skill Based Top~Down Progressive",
  "Skill Based Low High",
];

final List<String> callStrategies2 = [
  "Essential",
  "Ring All",
  "Random",
  "Pro",
  "Longest Idle Agent",
  "Round Robin",
  "Agent With Least Talk Time",
  "Agent With Fewest Calls",
  "Top Down",
  "Pro+",
  "Ring All",
  "Random",
  "Round Robin",
  "Agent With Fewest Calls",
  "Ring Progressively",
  "Top Down",
];

final List<String> infoStrategies = [
  "Essential",
  "A method where incoming calls are simultaneously directed to multiple devices or extensions, enabling several individuals to answer the call simultaneously.",
  "Directs incoming calls to a group of agents or devices in a random order. This approach helps distribute workload evenly among team members.",
  "Pro",
  "Prioritize calls based on the duration the agent has been available in the queue. It ensures fairness by directing calls to the agent who has been available the longest, reducing overall waiting times.",
  "Evenly distribute incoming calls to agents in a circular order. This rotation ensures an equal distribution of calls, avoiding workload imbalances among agents.",
  "Directs incoming calls to the agent who has spent the least time on previous calls. This method aims to distribute workload evenly among agents, ensuring fair opportunities for all team members.",
  "Directs incoming calls to agents with the least number of previously resolved calls. This promotes fairness by preventing any single agent from consistently handling more calls, ensuring an even distribution of workload among the team.",
  "Commencing with the top-ranked member in the \"Assignments\" tab, the system will progress down the list only if that user is occupied. prioritizing agents based on their predefined order",
  "Pro+",
  "Distributed incoming calls are directed to all available agents, but it prioritizes agents with pre-defined specific skills relevant to the caller's needs.",
  "Direct incoming calls to agents based on their specific skills. This approach ensures a fair distribution of tasks, optimizing efficiency and expertise in addressing customer needs.",
  "Distribute incoming calls among agents based on their specific skills in a circular order. This ensures a fair distribution of tasks, optimizing expertise for diverse customer needs.",
  "Directs incoming calls to agents with the fewest resolved calls in a specific skill area. This strategy optimizes workload distribution, allowing agents with expertise in a particular skill set to address new issues efficiently.",
  "It employs a method akin to top-down ringing, yet with the added feature of persistently ringing prior members, culminating in a ring-all scenario.",
  "Distribute calls from the lowest specialized agent first but if not answered within a time frame the call will get elevated to a higher skill level.",
];

Map queueDefinitions = {
  "queueNumber": "This is a system generated Extension number for easy identification and a reference point to manage your Queues (Not Editable)",
  "queueName": "This is a User Generated name for your Queues for easy identification for your own usage",
  "callStrategy": "This is a User Generated name for your Queues for easy identification for your own usage",
  "queuePriority": "Call queue priority is a system where certain Queues are given preference over others, ensuring that higher-priority Queue calls are addressed before lower-priority ones in the waiting line.",
  "queueSla":
      "SLA sets the standard response time in Seconds for calls. It defines the maximum time a caller should wait, ensuring timely and efficient customer service. Adhering to SLA enhances customer satisfaction by meeting expected response times.",
  "agentTimeoutLimit": "A predefined duration in seconds a call rings at an agent's station. If unanswered within this limit, the call will be directed to the next agent in the queue.",
  "wrapUpTime": "Set a Wrap up time in Seconds so after an agent finishes a call. It allows them to complete notes, and prepare for the next call, ensuring quality service without rushing.",
  "queueGreeting": "Set a pre-recorded message that welcomes callers while they are placed in the queue. It provides information, assures them of their place in line, and sets expectations.",
  "musicOnHold":
      "Play background music to entertain callers while they wait for assistance. It aims to enhance the caller's experience during the wait, providing a professional and engaging atmosphere while maintaining a sense of connectivity.",
  "messageOnHold":
      "Generate up to three Messages on Hold to deliver pre-recorded updates, promotions, and essential information to your callers in the queue. This ensures engagement and keeps them well-informed while awaiting assistance.",
  "queueMessageInterval": "A designated time interval, measured in seconds, allocated for the playback of your pre-recorded messages during the on-hold duration.",
  "queuePositionInterval":
      "A predefined duration in seconds a call rings in the Queue. If unanswered within this limit, the call may be redirected to another Queue or another action can occur for efficient call handling.",
  "queueTimeOut": "A predefined duration in seconds a call rings in the Queue. If unanswered within this limit, the call may be redirected to another Queue or another action can occur for efficient call handling.",
  "queueMaximumCallers": "Set a limit of callers that can be connected tot the queue. When this limit is reached, subsequent callers will be informed that all lines are busy and encouraged to try again later",
  "timeOutAction": "The Action that will happen when a call remains unanswered for a specified duration. It may redirect the call to another destination or follow a predefined course of action."
};

Map<String, String> headers = {
  HttpHeaders.acceptHeader: "*/*",
  HttpHeaders.contentTypeHeader: "application/json",
};
Map<String, String> headers2 = {HttpHeaders.acceptHeader: "*/*", HttpHeaders.contentTypeHeader: "application/x-www-form-urlencoded"};

List extensionGroups = [];
List extensionStatus = [];

dynamic cookie;
NumberFormat numberFormat = NumberFormat.decimalPattern('en_us');

Future<bool> storeSession(Map value) async {
  final localStorage = await SharedPreferences.getInstance();
  String encoded = json.encode(value);
  return localStorage.setString('session', encoded);
}

Future<Map> loadSession() async {
  final localStorage = await SharedPreferences.getInstance();
  String? encodedMap = localStorage.getString('session');
  if (encodedMap != null) {
    return json.decode(encodedMap);
  } else {
    return {};
  }
}

void navigate(BuildContext context, String str) {
  Navigator.of(context).pushNamed(str);
}

void navigateReplace(BuildContext context, String routeName) {
  Navigator.of(context).pushReplacementNamed(routeName);
}

showSnackbar(BuildContext context, String content, Color color) {
  return showTopSnackBar(
    Overlay.of(context),
    CustomSnackBar.success(
      message: content,
      textStyle: TextStyle(color: whiteColor, fontSize: headerSize, fontWeight: FontWeight.w500),
      textAlign: TextAlign.start,
      backgroundColor: color,
      icon: Container(),
    ),
  );
}

void showSnackbar3(BuildContext context, int type, String title, String content) async {
  if (type == 1) {
    ElegantNotification.success(title: Text(title), description: Text(content)).show(context);
  } else {
    ElegantNotification.error(title: Text(title), description: Text(content)).show(context);
  }
}

tableEntry2(String name, FontWeight fontWeight) {
  return Text(
    name,
    style: TextStyle(color: textColor, fontSize: paragraphSize, fontWeight: fontWeight),
    textAlign: TextAlign.start,
  );
}

Container tableHeader2(String name, FontWeight fontWeight) {
  return Container(
    padding: EdgeInsets.only(bottom: width * 0.0075),
    child: Text(
      name,
      style: TextStyle(color: greyColor3, fontSize: headerSize, fontWeight: fontWeight),
      textAlign: TextAlign.start,
    ),
  );
}

Widget loadingLinear(bool loading) {
  return loading ? const LinearProgressIndicator() : Container(height: 4);
}

Container footer(Color color) {
  return Container(
    padding: EdgeInsets.only(bottom: width * 0.005),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            "© 2023 RingQ $versionNumber. All rights reserved.",
            style: TextStyle(color: color, fontSize: headerSize, fontWeight: FontWeight.w300),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

Container tableHeader(String name, FontWeight fontWeight) {
  return Container(
    padding: const EdgeInsets.only(left: 5, top: 10, bottom: 10),
    child: Text(
      name,
      style: TextStyle(color: whiteColor, fontSize: headerSize, fontWeight: fontWeight),
      textAlign: TextAlign.start,
    ),
  );
}

Container tableEntry(String name, FontWeight fontWeight) {
  return Container(
    padding: const EdgeInsets.only(left: 5),
    child: Text(
      name,
      style: TextStyle(color: textColor, fontSize: paragraphSize, fontWeight: fontWeight),
      textAlign: TextAlign.start,
    ),
  );
}

Container tableEntry3(String name, FontWeight fontWeight) {
  return Container(
    padding: const EdgeInsets.only(left: 10, top: 5),
    child: Text(
      name,
      style: TextStyle(color: primaryColor, fontSize: paragraphSize, fontWeight: fontWeight),
      textAlign: TextAlign.start,
    ),
  );
}

Container tableHeader3(String name, Color color, FontWeight fontWeight) {
  return Container(
    padding: EdgeInsets.only(left: width * 0.01, top: width * 0.0075, bottom: width * 0.0075),
    child: Text(
      name,
      style: TextStyle(color: color, fontSize: headerSize, fontWeight: fontWeight),
      textAlign: TextAlign.start,
    ),
  );
}

extension StringExtensions on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

String getDialSubContent(String input) {
  switch (input) {
    case "2":
      return "ABC";
    case "3":
      return "DEF";
    case "4":
      return "GHI";
    case "5":
      return "JKL";
    case "6":
      return "MNO";
    case "7":
      return "PQRS";
    case "8":
      return "TUV";
    case "9":
      return "WXYZ";
    case "0":
      return "+";
    default:
      return "";
  }
}

String digitalFormat(Duration d) {
  if (d.inHours > 0) {
    return d.toString().split('.').first.padLeft(8, "0");
  } else {
    return d.toString().split('.').first.replaceFirst("0:", "");
  }
}

showContact(BuildContext context, Map content, Color statusColor, SIPUAHelper helper) {
  showModalBottomSheet(
    context: context,
    isDismissible: true,
    isScrollControlled: true,
    backgroundColor: backgroundColor,
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.965,
        maxChildSize: 0.965,
        minChildSize: 0.965,
        expand: true,
        builder: (context, scrollController) {
          return SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: appbarColor,
                  leading: IconButton(
                    icon: const Icon(
                      Boxicons.bx_x,
                      color: backgroundColor,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  title: const Text(
                    "Contact",
                    style: TextStyle(
                      color: backgroundColor,
                    ),
                  ),
                  centerTitle: true,
                  elevation: 0.0,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.only(top: width * 0.04, bottom: width * 0.04),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: statusColor,
                          child: const CircleAvatar(
                            radius: 45,
                            backgroundColor: greyColor,
                            child: Icon(
                              Boxicons.bxs_user,
                              color: primaryColor,
                              size: 45,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        content["firstname"] + " " + content["lastname"],
                        style: TextStyle(
                          color: textColor,
                          fontSize: headerSize * 1.1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        content["username"],
                        style: TextStyle(
                          color: textColor,
                          fontSize: headerSize * 1.05,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(left: width * 0.06, right: width * 0.06, top: width * 0.04, bottom: width * 0.04),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: const BoxDecoration(color: secondaryColor2, borderRadius: BorderRadius.all(Radius.circular(8))),
                                margin: EdgeInsets.only(left: width * 0.005, right: width * 0.005),
                                padding: EdgeInsets.only(top: width * 0.02, bottom: width * 0.02),
                                child: IconButton(
                                  iconSize: headerSize * 2,
                                  onPressed: () async {
                                    destination = content["extension"];
                                    MediaStream mediaStream;
                                    mediaStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
                                    helper.call(destination, voiceOnly: true, mediaStream: mediaStream).then((value) {});
                                  },
                                  icon: Icon(
                                    Boxicons.bx_phone_call,
                                    color: textColor,
                                    size: headerSize * 2,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                decoration: const BoxDecoration(color: secondaryColor2, borderRadius: BorderRadius.all(Radius.circular(8))),
                                margin: EdgeInsets.only(left: width * 0.005, right: width * 0.005),
                                padding: EdgeInsets.only(top: width * 0.02, bottom: width * 0.02),
                                child: IconButton(
                                  iconSize: headerSize * 2,
                                  onPressed: () async {
                                    destination = content["extension"];
                                    MediaStream mediaStream;
                                    mediaStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
                                    helper.call(destination, voiceOnly: true, mediaStream: mediaStream).then((value) {});
                                  },
                                  icon: Icon(
                                    Boxicons.bx_voicemail,
                                    color: textColor,
                                    size: headerSize * 2,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                decoration: const BoxDecoration(color: secondaryColor2, borderRadius: BorderRadius.all(Radius.circular(8))),
                                margin: EdgeInsets.only(left: width * 0.005, right: width * 0.005),
                                padding: EdgeInsets.only(top: width * 0.02, bottom: width * 0.02),
                                child: IconButton(
                                  iconSize: headerSize * 2,
                                  onPressed: () {
                                    //  launchUrl(Uri(scheme: "mailto", path: content["email"]));
                                  },
                                  icon: Icon(
                                    Boxicons.bx_mail_send,
                                    color: textColor,
                                    size: headerSize * 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.only(left: width * 0.08),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.only(top: width * 0.02, bottom: width * 0.02),
                                  child: Text(
                                    content["extension"].toString().length > 4 ? "Phone" : "Extension",
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: paragraphSize * 1.2,
                                      fontWeight: FontWeight.w300,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                Text(
                                  content["extension"],
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: paragraphSize * 1.2,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                                Container(
                                  padding: EdgeInsets.only(top: width * 0.06, bottom: width * 0.02),
                                  child: Text(
                                    "Email",
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: paragraphSize * 1.2,
                                      fontWeight: FontWeight.w300,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                Text(
                                  content["email"],
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: paragraphSize * 1.2,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

List countries = [
  "Afghanistan",
  "Albania",
  "Algeria",
  "American Samoa",
  "Andorra",
  "Angola",
  "Anguilla",
  "Antarctica",
  "Antigua and Barbuda",
  "Argentina",
  "Armenia",
  "Aruba",
  "Australia",
  "Austria",
  "Azerbaijan",
  "Bahamas",
  "Bahrain",
  "Bangladesh",
  "Barbados",
  "Belarus",
  "Belgium",
  "Belize",
  "Benin",
  "Bermuda",
  "Bhutan",
  "Bolivia",
  "Bonaire",
  "Bosnia and Herzegovina",
  "Botswana",
  "Bouvet Island",
  "Brazil",
  "British Indian Ocean Territory",
  "Brunei Darussalam",
  "Bulgaria",
  "Burkina Faso",
  "Burundi",
  "Cambodia",
  "Cameroon",
  "Canada",
  "Cape Verde",
  "Cayman Islands",
  "Central African Republic",
  "Chad",
  "Chile",
  "China",
  "Christmas Island",
  "Cocos (Keeling) Islands",
  "Colombia",
  "Comoros",
  "Congo",
  "Democratic Republic of the Congo",
  "Cook Islands",
  "Costa Rica",
  "Croatia",
  "Cuba",
  "Curaçao",
  "Cyprus",
  "Czech Republic",
  "Côte d'Ivoire",
  "Denmark",
  "Djibouti",
  "Dominica",
  "Dominican Republic",
  "Ecuador",
  "Egypt",
  "El Salvador",
  "Equatorial Guinea",
  "Eritrea",
  "Estonia",
  "Ethiopia",
  "Falkland Islands (Malvinas)",
  "Faroe Islands",
  "Fiji",
  "Finland",
  "France",
  "French Guiana",
  "French Polynesia",
  "French Southern Territories",
  "Gabon",
  "Gambia",
  "Georgia",
  "Germany",
  "Ghana",
  "Gibraltar",
  "Greece",
  "Greenland",
  "Grenada",
  "Guadeloupe",
  "Guam",
  "Guatemala",
  "Guernsey",
  "Guinea",
  "Guinea-Bissau",
  "Guyana",
  "Haiti",
  "Heard Island and McDonald Islands",
  "Holy See (Vatican City State)",
  "Honduras",
  "Hong Kong",
  "Hungary",
  "Iceland",
  "India",
  "Indonesia",
  "Iran",
  "Iraq",
  "Ireland",
  "Isle of Man",
  "Israel",
  "Italy",
  "Jamaica",
  "Japan",
  "Jersey",
  "Jordan",
  "Kazakhstan",
  "Kenya",
  "Kiribati",
  "Democratic People's Republic of Korea",
  "Republic of Korea",
  "Kuwait",
  "Kyrgyzstan",
  "Lao People's Democratic Republic",
  "Latvia",
  "Lebanon",
  "Lesotho",
  "Liberia",
  "Libya",
  "Liechtenstein",
  "Lithuania",
  "Luxembourg",
  "Macao",
  "Macedonia",
  "Madagascar",
  "Malawi",
  "Malaysia",
  "Maldives",
  "Mali",
  "Malta",
  "Marshall Islands",
  "Martinique",
  "Mauritania",
  "Mauritius",
  "Mayotte",
  "Mexico",
  "Micronesia",
  "Moldova ",
  "Monaco",
  "Mongolia",
  "Montenegro",
  "Montserrat",
  "Morocco",
  "Mozambique",
  "Myanmar",
  "Namibia",
  "Nauru",
  "Nepal",
  "Netherlands",
  "New Caledonia",
  "New Zealand",
  "Nicaragua",
  "Niger",
  "Nigeria",
  "Niue",
  "Norfolk Island",
  "Northern Mariana Islands",
  "Norway",
  "Oman",
  "Pakistan",
  "Palau",
  "Palestine",
  "Panama",
  "Papua New Guinea",
  "Paraguay",
  "Peru",
  "Philippines",
  "Pitcairn",
  "Poland",
  "Portugal",
  "Puerto Rico",
  "Qatar",
  "Romania",
  "Russian Federation",
  "Rwanda",
  "Reunion",
  "Saint Barthelemy",
  "Saint Helena",
  "Saint Kitts and Nevis",
  "Saint Lucia",
  "Saint Martin (French part)",
  "Saint Pierre and Miquelon",
  "Saint Vincent and the Grenadines",
  "Samoa",
  "San Marino",
  "Sao Tome and Principe",
  "Saudi Arabia",
  "Senegal",
  "Serbia",
  "Seychelles",
  "Sierra Leone",
  "Singapore",
  "Sint Maarten (Dutch part)",
  "Slovakia",
  "Slovenia",
  "Solomon Islands",
  "Somalia",
  "South Africa",
  "South Georgia and the South Sandwich Islands",
  "South Sudan",
  "Spain",
  "Sri Lanka",
  "Sudan",
  "Suriname",
  "Svalbard and Jan Mayen",
  "Swaziland",
  "Sweden",
  "Switzerland",
  "Syrian Arab Republic",
  "Taiwan",
  "Tajikistan",
  "United Republic of Tanzania",
  "Thailand",
  "Timor-Leste",
  "Togo",
  "Tokelau",
  "Tonga",
  "Trinidad and Tobago",
  "Tunisia",
  "Turkey",
  "Turkmenistan",
  "Turks and Caicos Islands",
  "Tuvalu",
  "Uganda",
  "Ukraine",
  "United Arab Emirates",
  "United Kingdom",
  "United States",
  "United States Minor Outlying Islands",
  "Uruguay",
  "Uzbekistan",
  "Vanuatu",
  "Venezuela",
  "Viet Nam",
  "British Virgin Islands",
  "US Virgin Islands",
  "Wallis and Futuna",
  "Western Sahara",
  "Yemen",
  "Zambia",
  "Zimbabwe",
  "Aland Islands"
];

Future<void> playRecording(Uint8List bytes) async {
  await AudioPlayer.clearAssetCache();
  final AudioPlayer audioPlayer = AudioPlayer();
  try {
    audioPlayer.setAudioSource(VoicemailSource2(bytes)).then((value) {
      audioPlayer.play();
    });
  } catch (e) {
    debugPrint("Error loading audio source: $e");
  }
}

class VoicemailSource2 extends StreamAudioSource {
  final Uint8List _buffer;

  VoicemailSource2(this._buffer) : super(tag: 'MyAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: (end ?? _buffer.length) - (start ?? 0),
      offset: start ?? 0,
      stream: Stream.fromIterable([_buffer.sublist(start ?? 0, end)]),
      contentType: 'audio/x-wav',
    );
  }
}

class VoicemailSource extends StreamAudioSource {
  final Uint8List _buffer;

  VoicemailSource(this._buffer) : super(tag: 'MyAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: (end ?? _buffer.length) - (start ?? 0),
      offset: start ?? 0,
      stream: Stream.fromIterable([_buffer.sublist(start ?? 0, end)]),
      contentType: 'audio/wav',
    );
  }
}

String avatarPath(String subdomain, String image) {
  if (image.isNotEmpty) {
    return "https://$subdomain:8443/avr/$image";
  }
  return "https://$subdomain:8443/img/ringq-square.png";
}

bool isNumeric(String str) {
  return double.tryParse(str) != null;
}

List assignSchedule(int startingHour, int startingMinute, int endingHour, int endingMinute) {
  return [startingHour * 60 + startingMinute, endingHour * 60 + endingMinute + 1];
}

Container displaySchedule(int type, List timeSchedule) {
  if (timeSchedule.isNotEmpty) {
    String startHour = Duration(minutes: int.parse(timeSchedule[0].toString())).inHours.toString();
    String startMinutes = Duration(minutes: int.parse(timeSchedule[0].toString())).inMinutes.remainder(60) < 10
        ? "0${Duration(minutes: int.parse(timeSchedule[0].toString())).inMinutes.remainder(60)}"
        : Duration(minutes: int.parse(timeSchedule[0].toString())).inMinutes.remainder(60).toString();
    String endHour = Duration(minutes: int.parse(timeSchedule[1].toString())).inHours.toString();
    String endMinutes = Duration(minutes: int.parse(timeSchedule[1].toString())).inMinutes.remainder(60) < 10
        ? "0${Duration(minutes: int.parse(timeSchedule[1].toString()) - 1).inMinutes.remainder(60)}"
        : Duration(minutes: int.parse(timeSchedule[1].toString()) - 1).inMinutes.remainder(60).toString();

    if ("$startHour:$startMinutes" == "0:00" && ("$endHour:$endMinutes" == "0:00" || "$endHour:$endMinutes" == "24:059")) {
      return Container(
        margin: EdgeInsets.only(top: width * 0.0035),
        child: const Text(
          "All Day",
          textAlign: TextAlign.center,
          style: TextStyle(color: primaryColor),
        ),
      );
    }
    return Container(
      margin: EdgeInsets.only(top: width * 0.0035),
      child: Text(
        "$startHour:$startMinutes - $endHour:$endMinutes",
        textAlign: TextAlign.center,
        style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
      ),
    );
  }
  return Container(
    margin: EdgeInsets.only(top: width * 0.0035),
    child: Text(
      type == 1 ? "All Day" : "None",
      style: const TextStyle(color: textColor2),
    ),
  );
}

Text display2Schedule(List timeSchedule) {
  if (timeSchedule.isNotEmpty) {
    String startHour = Duration(minutes: int.parse(timeSchedule[0].toString())).inHours.toString();
    String startMinutes = Duration(minutes: int.parse(timeSchedule[0].toString())).inMinutes.remainder(60) < 10
        ? "0${Duration(minutes: int.parse(timeSchedule[0].toString())).inMinutes.remainder(60)}"
        : Duration(minutes: int.parse(timeSchedule[0].toString())).inMinutes.remainder(60).toString();
    String endHour = Duration(minutes: int.parse(timeSchedule[1].toString())).inHours.toString();
    String endMinutes = Duration(minutes: int.parse(timeSchedule[1].toString())).inMinutes.remainder(60) < 10
        ? "0${Duration(minutes: int.parse(timeSchedule[1].toString()) - 1).inMinutes.remainder(60)}"
        : Duration(minutes: int.parse(timeSchedule[1].toString()) - 1).inMinutes.remainder(60).toString();

    if ("$startHour:$startMinutes" == "0:00" && ("$endHour:$endMinutes" == "0:00" || "$endHour:$endMinutes" == "24:059")) {
      return const Text(
        "All Day",
        textAlign: TextAlign.start,
        style: TextStyle(color: whiteColor),
      );
    }
    return Text(
      "$startHour:$startMinutes - $endHour:$endMinutes",
      textAlign: TextAlign.start,
      style: const TextStyle(color: whiteColor, fontWeight: FontWeight.bold),
    );
  }
  return const Text(
    "All Day",
    style: TextStyle(color: whiteColor),
  );
}

Container title(String value, String value2) {
  return Container(
    padding: EdgeInsets.only(top: width * 0.005, bottom: width * 0.005),
    child: Row(
      children: [
        Text(
          value,
          style: TextStyle(
            color: primaryColor,
            fontSize: headerSize,
          ),
        ),
        Text(
          value2,
          style: TextStyle(
            color: value2 == "*" ? redColor : primaryColor,
            fontSize: headerSize,
          ),
        ),
      ],
    ),
  );
}

Container subtitle(String value) {
  return Container(
    padding: EdgeInsets.only(top: width * 0.005),
    child: Text(
      value,
      style: TextStyle(
        fontSize: paragraphSize,
        fontWeight: FontWeight.w400,
        color: primaryColor2,
      ),
    ),
  );
}

Container dropdown(List<DropdownMenuItem<String>> items, String value1, value2) {
  return Container(
    margin: const EdgeInsets.only(left: 16, right: 16),
    padding: const EdgeInsets.only(left: 10, right: 10),
    decoration: BoxDecoration(
      color: primaryColor,
      borderRadius: BorderRadius.circular(10.0),
    ),
    height: 40,
    child: Row(
      children: [
        Expanded(
          child: DropdownButton(
            isExpanded: true,
            underline: const SizedBox(),
            alignment: AlignmentDirectional.centerEnd,
            dropdownColor: primaryColor2,
            style: TextStyle(
              color: whiteColor,
              fontSize: paragraphSize,
            ),
            borderRadius: BorderRadius.circular(10),
            items: items,
            value: value1,
            onChanged: value2,
          ),
        ),
      ],
    ),
  );
}

Container dropdownItem(String value) {
  return Container(
    padding: EdgeInsets.only(left: value.toString().contains("-") || value.toString().contains("Hangup") || value.toString().contains("Voicemail") ? 8 : 0),
    child: Text(
      value,
      style: TextStyle(
          color: whiteColor, fontSize: paragraphSize, fontWeight: value.toString().contains("-") || value.toString().contains("Hangup") || value.toString().contains("Voicemail") ? FontWeight.w300 : FontWeight.w600),
    ),
  );
}

TextFormField textFormField(TextEditingController controller, String validator) {
  return TextFormField(
    controller: controller,
    showCursor: false,
    readOnly: validator == "Please enter extension." || validator == "Please enter Queue extension." ? true : false,
    style: TextStyle(color: whiteColor, fontSize: paragraphSize),
    textAlign: TextAlign.start,
    keyboardType: TextInputType.name,
    decoration: inputDecoration,
    validator: validator.isNotEmpty
        ? (value) {
            return value!.isEmpty ? validator : null;
          }
        : null,
  );
}

TextField textForm2Field(TextEditingController controller, String validator) {
  return TextField(
      autofocus: false,
      showCursor: false,
      controller: controller,
      readOnly: validator == "Please enter extension." || validator == "Please enter Queue extension." ? true : false,
      style: TextStyle(color: whiteColor, fontSize: paragraphSize),
      textAlign: TextAlign.start,
      keyboardType: TextInputType.number,
      decoration: inputDecoration,
      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]);
}

TextField textForm3Field(int index, List content) {
  return TextField(
      controller: TextEditingController(text: content[index].toString()),
      autofocus: false,
      showCursor: false,
      onChanged: (a) {
        content[index] = a;
      },
      style: TextStyle(color: whiteColor, fontSize: paragraphSize),
      textAlign: TextAlign.start,
      keyboardType: TextInputType.number,
      decoration: inputDecoration,
      inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]);
}

TextField textForm4Field(int index, List content) {
  return TextField(
      controller: TextEditingController(text: content[index].toString()),
      autofocus: false,
      showCursor: false,
      onChanged: (a) {
        content[index] = a;
      },
      style: TextStyle(color: whiteColor, fontSize: paragraphSize),
      textAlign: TextAlign.start,
      keyboardType: TextInputType.number,
      decoration: inputDecoration);
}

InputDecoration inputDecoration = InputDecoration(
  isDense: true,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: const BorderSide(color: primaryColor, width: 2),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: const BorderSide(color: primaryColor, width: 2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: const BorderSide(color: primaryColor2, width: 2.5),
  ),
  filled: true,
  errorStyle: TextStyle(
    color: whiteColor,
    fontSize: paragraphSize,
    fontWeight: FontWeight.w600,
  ),
  hintText: "",
  fillColor: primaryColor,
);

InputDecoration inputDecoration2 = InputDecoration(
  isDense: true,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: const BorderSide(color: whiteColor, width: 2),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: const BorderSide(color: whiteColor, width: 2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: const BorderSide(color: whiteColor, width: 2.5),
  ),
  filled: true,
  counterStyle: TextStyle(
    color: primaryColor,
    fontSize: paragraphSize,
    fontWeight: FontWeight.w600,
  ),
  errorStyle: TextStyle(
    color: whiteColor,
    fontSize: paragraphSize,
    fontWeight: FontWeight.w600,
  ),
  hintText: "",
  fillColor: primaryColor,
);

String ivrParamOutput(bool voicemail, String extension) {
  return voicemail ? "transfer *99$extension XML $ringqServer" : "transfer $extension XML $ringqServer";
}

Text tableEntry1(String name, FontWeight fontWeight) {
  return Text(
    name.toString(),
    style: TextStyle(color: Colors.indigo.shade100, fontSize: paragraphSize, fontWeight: fontWeight),
    textAlign: TextAlign.start,
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  );
}

Text tableHeader1(String name, FontWeight fontWeight) {
  return Text(
    name,
    style: TextStyle(color: Colors.indigo.shade100, fontSize: headerSize, fontWeight: fontWeight),
    textAlign: TextAlign.center,
  );
}

void prettyLog(dynamic message) {
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  String prettyString;
  try {
    prettyString = encoder.convert(message);
  } catch (e) {
    prettyString = message.toString();
  }
  debugPrint(prettyString);
}

String getMonth(int mon) {
  if (mon == 1) {
    return "Jan";
  }
  if (mon == 2) {
    return "Feb";
  }
  if (mon == 3) {
    return "Mar";
  }
  if (mon == 4) {
    return "Apr";
  }
  if (mon == 5) {
    return "May";
  }
  if (mon == 6) {
    return "Jun";
  }
  if (mon == 7) {
    return "Jul";
  }
  if (mon == 8) {
    return "Aug";
  }
  if (mon == 9) {
    return "Sep";
  }
  if (mon == 10) {
    return "Oct";
  }
  if (mon == 11) {
    return "Nov";
  }
  if (mon == 12) {
    return "Dec";
  }
  return "";
}

Text tableHeader4(String name, FontWeight fontWeight) {
  return Text(
    name,
    style: TextStyle(color: Colors.indigo.shade100, fontSize: paragraphSize, fontWeight: fontWeight),
    textAlign: TextAlign.start,
  );
}

class BlinkingWidget extends StatefulWidget {
  final Widget child;
  final Duration? duration;

  const BlinkingWidget({
    super.key,
    required this.child,
    this.duration,
  });

  @override
  State<BlinkingWidget> createState() => _BlinkingWidgetState();
}

class _BlinkingWidgetState extends State<BlinkingWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 600),
      lowerBound: 0.4,
      vsync: this,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });

    _controller.forward();
  }

  @override
  dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _controller.value,
          child: widget.child,
        ),
        child: widget.child,
      );
}

IconButton infoButton(String content) {
  return IconButton(onPressed: null, icon: Icon(Boxicons.bxs_info_circle, color: primaryColor2, size: headerSize), tooltip: content);
} 

displayLogo(context) {
  return Row( 
    children: [
      const SizedBox(width: 10,),
      GestureDetector(
        onTap: () {
          // print(callInbound);
        },
        child: Image.asset('images/logo4.png', width: 120),
      ),
      const Spacer(),
      const SizedBox(width: 10,), 
    ],
  );
}