// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:auto_size_text/auto_size_text.dart';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:js/js_util.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'assets.dart';
import 'initiation.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter/material.dart';
import 'package:boxicons/boxicons.dart';
import 'package:audioplayers/audioplayers.dart';

class Dialer extends StatefulWidget {
  final String title;
  final String extensionNo;
  final String username;
  final String password;
  final String callNumber;

  const Dialer({
    super.key,
    required this.title,
    required this.extensionNo,
    required this.username,
    required this.password,
    required this.callNumber
  });

  @override
  State<Dialer> createState() => _DialerState();
}

class _DialerState extends State<Dialer> implements SipUaHelperListener {
  bool _dialPad = false;
  FocusNode focusNode = FocusNode();
  final AudioPlayer _player = AudioPlayer();
  final SIPUAHelper sipUAHelper = SIPUAHelper();

  @override
  void initState() {
    super.initState();
    _initializeCallFlow();
  }

  _initializeCallFlow() async { 
    await Future.delayed(const Duration(seconds: 1));
    sipUAHelper.addSipUaHelperListener(this);
    UaSettings settings = UaSettings();
    settings.webSocketSettings.allowBadCertificate = false;
    settings.transportType = TransportType.WS;
    settings.dtmfMode = DtmfMode.RFC2833;
    settings.displayName = widget.username;
    settings.password = widget.password;
    settings.uri = 'sip:${widget.extensionNo}@demo.us1.ringq.ai:7443';
    settings.webSocketUrl = 'wss://demo.us1.ringq.ai:7443';
    settings.userAgent = 'RingQ Webapp w$versionNumber';
    sipUAHelper.start(settings);

    setState(() {
      extensionNo = widget.extensionNo;
      username = widget.username;
    });

    if (widget.callNumber.isNotEmpty) {
      setState(() => destination = widget.callNumber);
 
      await Future.delayed(const Duration(seconds: 1));
      _performCall(context, true);
    }
  }

  void _performCall(BuildContext context, [bool voiceOnly = false]) async {
    MediaStream mediaStream;
    final mediaConstraints = <String, dynamic>{'audio': true, 'video': false};
    mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    sipUAHelper.call(destination, voiceOnly: voiceOnly, mediaStream: mediaStream).then((value) {});
  }

  Expanded _dialNumber(String number) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0.0,
          shape: const CircleBorder(),
        ),
        onPressed: () {
          setState(() {
            playBeepSound();
            destination += number;
            destinationName = "";
            if (destination == destination) {
              destinationName = destinationName;
            }
          });
        },
        onLongPress: () {
          if (number == "0") {
            setState(() {
              playBeepSound();
              destination += "+";
              destinationName = "";
              if (destination == destination) {
                destinationName = destinationName;
              }
            });
          }
        },
        child: Container(
          padding: EdgeInsets.all(subParagraphSize),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: headerSize * 1.5,
                  color: whiteColor,
                  fontWeight: FontWeight.w400,
                  fontFamily: "primaryFont",
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                getDialSubContent(number),
                style: TextStyle(
                  fontSize: subParagraphSize,
                  color: whiteColor,
                  fontWeight: FontWeight.w300,
                  fontFamily: "primaryFont",
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 20, 28, 52),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  // print(callInbound);
                },
                child: Container(
                  padding: const EdgeInsets.only(left: 8),
                  child: Image.asset('images/logo4.png', width: 110),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          children: [
                            AutoSizeText(
                              sipUAHelper.registerState.state == RegistrationStateEnum.REGISTERED ? "Online (${widget.extensionNo})"  : "Offline (${widget.extensionNo})",
                              style: TextStyle(
                                color: whiteColor,
                                fontSize: paragraphSize,
                                fontFamily: "primaryFont",
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ), 
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[ 
                      destination.isNotEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Spacer(),
                                Expanded(
                                  flex: 6,
                                  child: AutoSizeText(
                                    destination,
                                    style: TextStyle(
                                      fontSize: headerSize * 1.8,
                                      color: whiteColor,
                                      fontWeight: FontWeight.w300,
                                      fontFamily: "primaryFont",
                                    ),
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            )
                          : Container(),
                      destinationName.isNotEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Spacer(),
                                Expanded(
                                  flex: 2,
                                  child: AutoSizeText(
                                    destinationName,
                                    style: TextStyle(
                                      fontSize: headerSize * 1.6,
                                      color: whiteColor,
                                      fontWeight: FontWeight.w300,
                                      fontFamily: "primaryFont",
                                    ),
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            )
                          : Container(), 
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    _dialNumber("1"),
                    _dialNumber("2"),
                    _dialNumber("3"),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    _dialNumber("4"),
                    _dialNumber("5"),
                    _dialNumber("6"),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    _dialNumber("7"),
                    _dialNumber("8"),
                    _dialNumber("9"),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    _dialNumber("*"),
                    _dialNumber("0"),
                    _dialNumber("#"),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Container()),
                    Expanded(
                      child: CircleAvatar(
                        backgroundColor: primaryColor2, 
                        child: IconButton(
                          onPressed: () {
                            if (destination.isNotEmpty) {
                              _performCall(context, true);
                            }
                          }, 
                          color: primaryColor,
                          icon: const Icon(
                            CarbonIcons.phone_filled, 
                            color: whiteColor,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0.0,
                          shape: const CircleBorder(),
                        ),
                        onPressed: () {
                          if (destination.isNotEmpty) {
                            setState(() {
                              playBeepSound();
                              destinationName = "";
                              destination = destination.substring(0, destination.length - 1);
                              if (destination == destination) {
                                destinationName = destinationName;
                              }
                            });
                          } else {
                            destinationName = "";
                            if (destination == destination) {
                              destinationName = destinationName;
                            }
                            setState(() {
                              _dialPad = false;
                            });
                          }
                        },
                        onLongPress: () {
                          if (destination.isNotEmpty) {
                            setState(() {
                              destination = "";
                            });
                          } else {
                            setState(() {
                              _dialPad = false;
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(headerSize * 1.01),
                          child: Icon(LucideIcons.delete, size: headerSize * 1.3, color: whiteColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          ),
        ],
      )
    );
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void callStateChanged(Call call, CallState callState) async {
    if (callState.state == CallStateEnum.CALL_INITIATION) {
      dialOpen = true;
      callInbound = call;
      if (call.direction == "INCOMING") {
        toggleSoftphonePanel(true);
        destination = "";
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => InitiationPage(helper: sipUAHelper)),
          );
        });
      }
      if (call.direction == "OUTGOING" && callInbound != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => InitiationPage(helper: sipUAHelper)),
          );
        });
      }
    }
    if (callState.state == CallStateEnum.ACCEPTED) {
      setState(() {
        _player.stop();
      });
    }
    if (callState.state == CallStateEnum.FAILED) {
      setState(() {
        dialOpen = true;
        // callInbound =null;
        _player.stop();
      });
    }
  }

  @override
  void registrationStateChanged(RegistrationState state) async {
    setState(() {});
  }

  @override
  void transportStateChanged(TransportState state) {
    // debugPrint('<-- TRANSPORT  -->');
    // debugPrint(state.state.name);
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void onNewReinvite(ReInvite event) {
    // TODO: implement onNewReinvite
  }
}
