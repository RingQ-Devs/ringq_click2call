// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async'; 
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import '../assets.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter/material.dart'; 
import 'package:flutter/foundation.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

class InitiationPage extends StatefulWidget {
  final SIPUAHelper helper;
  const InitiationPage({required this.helper, Key? key}) : super(key: key);

  @override
  InitiationPageState createState() => InitiationPageState();
}

class InitiationPageState extends State<InitiationPage> implements SipUaHelperListener {
  bool _loading = false;
  bool _dialpad = false;
  bool _answered = false;
  bool _declined = false;
  bool _holdCall = false;
  bool _muteCall = false;
  bool _recordCall = false;
  bool _parkedCall = false;
  bool _transferring = false;
  List _searchLogs = [];
  List _extensionData = [];
  String _dmtf = "";
  String get _direction => callInbound!.direction;
  CallStateEnum _callState = CallStateEnum.NONE;
  SIPUAHelper? get helper => widget.helper;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer? _remoteRenderer = RTCVideoRenderer(); 
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();
  bool get voiceOnly => (_localStream == null || _localStream!.getVideoTracks().isEmpty) && (_remoteStream == null || _remoteStream!.getVideoTracks().isEmpty);
  final TextEditingController _searchController = TextEditingController();

  @override
  initState() {
    super.initState();
    _initRenderers();
    helper!.addSipUaHelperListener(this);
  }

  void _initRenderers() async {
    if (_localRenderer != null) {
      await _localRenderer!.initialize(); 
    } 
    if (_remoteRenderer != null) {
      await _remoteRenderer!.initialize(); 
    }
  }

  void _performMute() { 
    _muteCall
      ? callInbound!.unmute(true, false)
      : callInbound!.mute(true, false);
  }

  void _performHold() async {
    _holdCall
      ? callInbound!.unhold()
      : callInbound!.hold();
  }

  void _performDtmf(String tone) {
    callInbound!.sendDTMF(tone, {"interToneGap": 200});
    playBeepSound();
  }

  void _performRecord() async {
    setState(() => _recordCall = !_recordCall);
  }

  void _registerCallGet(String extension, String number, String queueNumber ) async {
    http.Response response;
    try {
      String trimmedQueueNumber = queueNumber.replaceAll("(", "").replaceAll(")", ""); 
      response = await http.get(
        Uri.parse("https://demo.us1.ringq.ai:8443/register/calllog/1/"+ username + "/"+ number +"/"+ trimmedQueueNumber),
      );
      Map content = json.decode(response.body);
      prettyLog(content["content"]);
      if (content["result"] == "success" && content["registered"] == "false") { 
        openFloatingWindow(content["content"]);
        // launchUrl(Uri.parse(content["content"]));
      }
    } catch (e) {
      setState(() {
        _loading = false;
        showSnackbar(context, "An error has occured.", redColor);
      });
    }
  }

  void _performAccept() async {
    debugPrint("<!-- THIS IS ACCEPT");
    MediaStream mediaStream;
    final mediaConstraints = <String, dynamic>{'audio': true, 'video': false};
    mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if (callInbound != null) {
      _answered = true;
      _stopWatchTimer.onStartTimer;
      invokeDialer('inbound', callInbound!.remote_identity!);
      _registerCallGet(extensionNo, callInbound!.remote_identity!, callInbound!.remote_display_name!); 

      callInbound?.answer(helper!.buildCallOptions(!false), mediaStream: mediaStream);
    }
  }

  void _performHangup() {
    if (!_answered) {
      setState(() => _declined = true ); 
      callInbound?.hangup({'status_code': 603});
    } else {
      callInbound?.hangup({'status_code': 603});
    }
  }

  void _handelStreams(CallState event) async {
    MediaStream? stream = event.stream;
    if (event.originator == "local") {
      if (_localRenderer != null) {
        _localRenderer!.srcObject = stream;
      }
      if (!kIsWeb && !WebRTC.platformIsDesktop) {
        event.stream?.getAudioTracks().first.enableSpeakerphone(false);
      }
      _localStream = stream;
    }
    if (event.originator == "remote") {
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
      _remoteStream = stream;
    }
  }

  void _navigateBack() async {
    destination = "";
    supervisorMode = 0;
    supervisorCall = "";
    if (_answered) {
      _stopWatchTimer.dispose();
      _clearStreams();
    } else {
      setState(() {
        _declined = true;
      });
    }
    Timer(const Duration(milliseconds: 100), () {
      callInbound = null;
      Navigator.of(context).pop();
    });
  }

  void _performSearch(String searchTerm) async {
    if (double.tryParse(searchTerm) != null) {
      _searchLogs = _extensionData.where((item) => item["extension"].toString().toLowerCase().contains(searchTerm)).toList();
      if (_searchLogs.isNotEmpty) {
        setState(() {
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } else {
      _searchLogs = _extensionData.where((item) => (item["firstname"] + item["lastname"]).toString().toLowerCase().contains(searchTerm)).toList();
      if (_searchLogs.isNotEmpty) {
        setState(() {
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Expanded dialNumber(String number) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.only(bottom: width * 0.01),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            shape: const CircleBorder(),
          ),
          onPressed: () {
            setState(() {
              _dmtf += number;
              _performDtmf(number);
            });
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: <Widget>[ 
          const SizedBox(height: 20),
          ClipOval(
            child: Image.asset(
              'images/logo5.png',
              width: 100,
              height: 100, 
              fit: BoxFit.cover,
            ),
          ), 
          const SizedBox(height: 10),
          Text(
            callInbound!.remote_display_name!,
            style: TextStyle(color: whiteColor, fontFamily: "primaryFont", fontSize: headerSize * 1.35, fontWeight: FontWeight.w300),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 5),
          Text(
            callInbound!.remote_identity!,
            style: TextStyle(color: whiteColor, fontFamily: "primaryFont", fontSize: headerSize * 1.35, fontWeight: FontWeight.w300),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          _answered == false && _direction == Direction.incoming.name.toUpperCase()
            ? Container()
            : _dialpad
              ? Container()
              : const Spacer(),
          _answered == false && _direction == Direction.incoming.name.toUpperCase()
            ? Container()
            : _dialpad
              ? Container()
              : StreamBuilder<int>(
                  stream: _stopWatchTimer.rawTime,
                  initialData: _stopWatchTimer.rawTime.value,
                  builder: (context, snapshot) {
                    final elapsedMilliseconds = snapshot.data ?? 0;
                    final displayTime = StopWatchTimer.getDisplayTime(
                      elapsedMilliseconds,
                      hours: elapsedMilliseconds >= 3600000,
                      milliSecond: false,
                    );
                    return Text(displayTime, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),);
                  },
                ),
          _answered == false && _direction == Direction.incoming.name.toUpperCase()
            ? Container()
            : _dialpad
              ? Container()
              : const Spacer(),
          _answered == false && _direction == Direction.incoming.name.toUpperCase()
            ? Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          _declined
                            ? Container()
                            : Transform.rotate(
                              angle: _direction == Direction.incoming.name.toUpperCase() ? 0 : 40.05,
                              child: AvatarGlow(
                                glowColor: _direction == Direction.incoming.name.toUpperCase() ? primaryColor2 : redColor,
                                child: CircleAvatar(
                                  backgroundColor: _direction == Direction.incoming.name.toUpperCase() ? primaryColor2 : redColor,
                                  radius: headerSize * 1.8,
                                  child: IconButton(
                                    onPressed: _performAccept,
                                    iconSize: headerSize * 1.8,
                                    color: primaryColor2,
                                    icon: Icon(
                                      CarbonIcons.phone_filled,
                                      size: headerSize * 1.8,
                                      color: whiteColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 50,),
                          _direction == Direction.incoming.name.toUpperCase()
                            ? Transform.rotate(
                                angle: 40.05,
                                child: CircleAvatar(
                                  backgroundColor: redColor,
                                  radius: headerSize * 1.8,
                                  child: IconButton(
                                    onPressed: _performHangup,
                                    iconSize: headerSize * 1.8,
                                    color: redColor,
                                    icon: Icon(
                                      CarbonIcons.phone_block_filled,
                                      size: headerSize * 1.8,
                                      color: whiteColor,
                                    ),
                                  ),
                                ),
                              )
                            : Container(),
                        ],
                      ),
                    ), 
                  ],
                ),
              )
            : _dialpad
                ? Column(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: <Widget>[
                              dialNumber("1"),
                              dialNumber("2"),
                              dialNumber("3"),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: <Widget>[
                              dialNumber("4"),
                              dialNumber("5"),
                              dialNumber("6"),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: <Widget>[
                              dialNumber("7"),
                              dialNumber("8"),
                              dialNumber("9"),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: <Widget>[
                              dialNumber("*"),
                              dialNumber("0"),
                              dialNumber("#"),
                            ],
                          ),
                          Row(
                            children: [
                              const Spacer(),
                              Expanded(
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _dialpad = _dialpad ? false : true;
                                    });
                                  },
                                  iconSize: headerSize * 1.8,
                                  icon: Icon(
                                    CarbonIcons.arrow_left,
                                    size: headerSize * 1.8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  )
                : Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (_callState == CallStateEnum.CONFIRMED) {
                                    if (_parkedCall == false) {
                                      _performHold();
                                    }
                                  }
                                },
                                iconSize: headerSize * 2,
                                icon: _parkedCall
                                    ? Icon(LucideIcons.pause, size: headerSize * 2, color: primaryColor2)
                                    : Icon(LucideIcons.pause, size: headerSize * 2, color: _holdCall ? primaryColor2 : whiteColor),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                "Hold",
                                style: _parkedCall
                                  ? TextStyle(color: primaryColor2, fontSize: paragraphSize, fontWeight: FontWeight.w300)
                                  : TextStyle(color: _holdCall ? primaryColor2 : whiteColor, fontSize: paragraphSize, fontWeight: FontWeight.w300),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              IconButton(
                                onPressed: () { 
                                  if (!_holdCall) { 
                                    _performMute();
                                  }
                                },
                                iconSize: headerSize * 2,
                                icon: Icon(_muteCall ? LucideIcons.micOff : LucideIcons.mic, size: headerSize * 2, color: _muteCall ? primaryColor2 : whiteColor),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                "Mute",
                                style: TextStyle(color: _recordCall ? primaryColor2 : whiteColor, fontSize: paragraphSize, fontWeight: FontWeight.w300),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Row(
                    //   children: [
                        // Expanded(
                        //   child: Column(
                        //     children: [
                        //       IconButton(
                        //         onPressed: () {
                        //           if (_callState == CallStateEnum.CONFIRMED) {
                        //             if (!_parkedCall) {
                        //               setState(() {
                        //                 _loading = true;
                        //                 _transferring = _transferring ? false : true;
                        //               });
                        //             }
                        //           }
                        //         },
                        //         iconSize: headerSize * 2,
                        //         icon: Icon(LucideIcons.repeat2, size: headerSize * 2, color: whiteColor),
                        //       ),
                        //       const SizedBox(
                        //         height: 10,
                        //       ),
                        //       Text(
                        //         "Transfer",
                        //         style: TextStyle(color: whiteColor, fontSize: paragraphSize, fontWeight: FontWeight.w300),
                        //         textAlign: TextAlign.center,
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        // Expanded(
                        //   child: Column(
                        //     children: [
                        //       CircleAvatar(
                        //         backgroundColor: backgroundColor,
                        //         radius: headerSize * 1.8,
                        //         child: IconButton(
                        //           onPressed: () {
                        //             callInbound!.refer("3000");
                        //           },
                        //           iconSize: headerSize * 1.8,
                        //           color: redColor,
                        //           icon: Icon(
                        //             CarbonIcons.star,
                        //             size: headerSize * 1.8,
                        //             color: whiteColor,
                        //           ),
                        //         ),
                        //       ),
                        //       const SizedBox(
                        //         height: 10,
                        //       ),
                        //       Text(
                        //         "Survey",
                        //         style: TextStyle(color: whiteColor, fontSize: paragraphSize, fontWeight: FontWeight.w300),
                        //         textAlign: TextAlign.center,
                        //       ),
                        //     ],
                        //   ),
                        // ),
                    //   ],
                    // ),
                    const SizedBox(height: 50,),
                    Container( 
                      color: Colors.white10,
                      child: Row(
                        children: [
                          // Expanded(
                          //   child: GestureDetector(
                          //     onTap: () {
                          //       if (_callState == CallStateEnum.CONFIRMED) {
                          //         setState(() {
                          //           _dialpad = _dialpad ? false : true;
                          //         });
                          //       }
                          //     },
                          //     child: Icon(Boxicons.bx_dialpad, size: headerSize * 1, color: whiteColor, opticalSize: headerSize * 2),
                          //   ),
                          // ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              color: redColor,
                              child: InkWell(
                                onTap: () {
                                  _performHangup();
                                },
                                child: Icon(CarbonIcons.phone_filled, size: headerSize * 2, color: whiteColor, opticalSize: headerSize * 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
        ],
      ),
    );
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    prettyLog({
      'file': 'initiation.dart',
      'callState.state': callState.state.toString()
    });

    if (callState.state == CallStateEnum.HOLD || callState.state == CallStateEnum.UNHOLD) {
      _holdCall = callState.state == CallStateEnum.HOLD;
      setState(() {});
      return;
    }
    if (callState.state == CallStateEnum.MUTED) {
      if (callState.audio!) _muteCall = true;
      setState(() {});
      return;
    }
    if (callState.state == CallStateEnum.UNMUTED) {
      if (callState.audio!) _muteCall = false;
      setState(() {});
      return;
    }
    if (callState.state != CallStateEnum.STREAM) {
      _callState = callState.state;
    }
    switch (callState.state) {
      case CallStateEnum.STREAM:
        _handelStreams(callState);
        break;
      case CallStateEnum.ENDED:
        _navigateBack();
        break;
      case CallStateEnum.FAILED:
        _navigateBack();
        break;
      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
        if (_direction == "INCOMING") {
          setState(() {
            _stopWatchTimer.onStartTimer();
            _loading = false;
          });
        }
        break;
      case CallStateEnum.ACCEPTED:
        if (_direction == "OUTGOING") {
          setState(() {
            _stopWatchTimer.onStartTimer();
            _loading = false;
          });
        }
        break;
      case CallStateEnum.CONFIRMED:
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
      case CallStateEnum.NONE:
      case CallStateEnum.CALL_INITIATION:
      case CallStateEnum.REFER:
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void registrationStateChanged(RegistrationState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  void _disposeRenderers() {
    if (_localRenderer != null) {
      _localRenderer!.dispose();
      _localRenderer = null;
    }
    if (_remoteRenderer != null) {
      _remoteRenderer!.dispose();
      _remoteRenderer = null;
    }
  }

  void _clearStreams() async {
    if (_localStream == null) return;
    List<MediaStreamTrack>? tracks = _localStream?.getTracks();
    for (var x = 0; x < tracks!.length; x++) {
      tracks[x].stop();
    }
    _localStream!.dispose();
    _localStream = null;
  }

  @override
  void deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
    _disposeRenderers();
  }

  @override
  void dispose() {
    super.dispose();
    _searchController.dispose();
  }

  @override
  void onNewReinvite(ReInvite event) {
    // TODO: implement onNewReinvite
  }

  Row avatarDisplayImage(int type) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: type == 2 ? width * 0.33 : width * 0.45,
          height: type == 2 ? width * 0.33 : width * 0.45,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.all(Radius.circular(height * 0.15)),
            border: Border.all(
              width: 8,
              color: primaryColor,
              style: BorderStyle.solid,
            ),
          ),
          child: CircleAvatar(
            radius: headerSize,
            backgroundColor: backgroundColor,
          ),
        ),
      ],
    );
  }

  Container avatarPlaceholder() {
    return Container(
      width: width * 0.33,
      height: width * 0.33,
      decoration: BoxDecoration(
        color: textColor2,
        borderRadius: BorderRadius.all(Radius.circular(height * 0.15)),
        border: Border.all(
          width: 8,
          color: primaryColor,
          style: BorderStyle.solid,
        ),
      ),
      child: const Icon(Icons.add, color: primaryColor),
    );
  }
}