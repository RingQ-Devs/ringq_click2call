// ignore_for_file: use_build_context_synchronously, deprecated_member_use, prefer_interpolation_to_compose_strings, unused_field, avoid_print

import 'package:auto_size_text/auto_size_text.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:js/js.dart'; 
import 'package:lucide_icons/lucide_icons.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'assets.dart'; 
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter/material.dart'; 
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Dialer extends StatefulWidget {
  const Dialer({ super.key,  });
  @override
  State<Dialer> createState() => _DialerState();
}

class _DialerState extends State<Dialer> implements SipUaHelperListener {
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer? _remoteRenderer = RTCVideoRenderer();
  CallStateEnum _callState = CallStateEnum.NONE;
  FocusNode focusNode = FocusNode();
  bool _dialPad = false;
  bool _parkedCall = false;
  bool _holdCall = false;
  bool _muteCall = false;
  bool _answered = false;
  bool _declined = false;
  final AudioPlayer _player = AudioPlayer();
  final SIPUAHelper sipUAHelper = SIPUAHelper();
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(); 

  @override
  void initState() {
    super.initState();
    _initializeCallFlow();
    _initRenderers();
  }

  _initializeCallFlow() async {
    var resultUserDetail = await getSfUserDetail();
    var userDetail = json.decode(resultUserDetail);
    prettyLog(userDetail);

    setState(() {
      sfUserId = userDetail['Id'];
      extentionNo = userDetail['SIP_Extension__c'];
      username = userDetail['SIP_Username__c'];
      password = userDetail['SIP_Password__c'];
      ringqServer =  userDetail['RingQ_Server__c'].replaceFirst(RegExp(r'^https://'), '');
    });

    await Future.delayed(const Duration(seconds: 1));
    sipUAHelper.addSipUaHelperListener(this);
    UaSettings settings = UaSettings();
    settings.webSocketSettings.allowBadCertificate = true;
    settings.transportType = TransportType.WS;
    settings.dtmfMode = DtmfMode.RFC2833;
    settings.displayName = username;
    settings.password = password;
    settings.uri = 'sip:$extentionNo@$ringqServer:7443';
    settings.webSocketUrl = 'wss://$ringqServer:7443';
    settings.userAgent = 'RingQ Webapp w$versionNumber';
    sipUAHelper.start(settings); 
 
    _getSearchOrder(ringqServer);

    await Future.delayed(const Duration(seconds: 1));

    CallListener.initialize();
    CallListener.onNewCall.listen((payload) async {
      var res = json.decode(payload);
      prettyLog(res);
      
      sfNavigateRecord(res['objectType'], res['number']);
      setState(() {
        destination = res['number'];
        entity = res['objectType'];
        sfUserId = res['Id'];
      });
      _performCall(context, true);

      await Future.delayed(const Duration(seconds: 1));

      _registerCallGet(username, callDirections!.remote_identity!, extentionNo, 'outbound', objectType: entity);
      sfToggleSoftphonePanelJS(true);
    });
  }

  _getSearchOrder(hostServer) async {
    try {
      final response = await http.post(Uri.parse('https://$hostServer:8443/register/calllog'), 
        body: {'dialer_name': "$username@$extentionNo"},
      );

      if (response.statusCode == 200) {
        var res = json.decode(response.body); 
        if (res['result'] == 'success') {
          setState(() {
            prioritySfSearchOrder = res['content']['priority'];
            prioritySfForm = res['content']['form'];
          });
        }
      } else {
        print('Failed to send POST request. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // prettyLog({
      //   'post': '/register/calllog',
      //   'error': e
      // });
    }
  }

  _performCall(BuildContext context, [bool voiceOnly = false]) async {
    MediaStream mediaStream;
    final mediaConstraints = <String, dynamic>{'audio': true, 'video': false};
    mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    sipUAHelper.call(destination, voiceOnly: voiceOnly, mediaStream: mediaStream).then((value) {});
  }

  _performAccept() async {
    debugPrint("<!-- THIS IS ACCEPT");
    MediaStream mediaStream;
    final mediaConstraints = <String, dynamic>{'audio': true, 'video': false};
    mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if (callDirections != null) {
      await _existContact(username, callDirections!.remote_identity!); 
      callDirections?.answer(sipUAHelper.buildCallOptions(!false), mediaStream: mediaStream);
      debugPrint("<!-- THIS IS ACCEP 1");
      sfSearchRecordJS(callDirections!.remote_identity!, prioritySfSearchOrder, prioritySfForm.replaceAll(RegExp(r's$'), ''), allowInterop((String attributeType) {
        debugPrint("<!-- THIS IS ACCEP 2");
        _registerCallGet(username, callDirections!.remote_identity!, extentionNo, 'inbound', objectType: attributeType);
      }));
    }
    _player.stop();
  }

  _registerCallGet(String sipUsername, String callerNumber, String callerDestination, String callDirection, {String objectType = ''}) async {
    prettyLog({
      'sipUsername': sipUsername,
      'callerNumber': callerNumber,
      'callerDestination': callerDestination,
      'callDirection': callDirection,
      'objectType': objectType,
      'userId': sfUserId,
    });

    await http.get(
      Uri.parse("https://$ringqServer:8443/register/calllog/1/"+ sipUsername + "/"+ callerNumber +"/"+ callerDestination +"/"+ callDirection +"/"+ objectType +"/"+ sfUserId,), 
    ); 
  }

  _existContact(String username, String callerNumber) async {
    try {
      final response = await http.get(
        Uri.parse("https://$ringqServer:8443/register/calllog/2/"+ username + "/"+ callerNumber), 
      );
      if (response.statusCode == 200) {
        var res = json.decode(response.body);
        prettyLog(res);
        return '';
      } else {
        print('Failed to send POST request. Status code: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      prettyLog({
        '_existContact error:': e
      });
      return '';
    }
  }

  _performHangup() {
    if (!_answered) {
      setState(() => _declined = true ); 
      callDirections?.hangup({'status_code': 603});
    } else {
      callDirections?.hangup({'status_code': 603});
    }
  }

  _initRenderers() async {
    if (_localRenderer != null) {
      await _localRenderer!.initialize(); 
    } 
    if (_remoteRenderer != null) {
      await _remoteRenderer!.initialize(); 
    }
  }

  _performMute() { 
    _muteCall
      ? callDirections!.unmute(true, false)
      : callDirections!.mute(true, false);
  }

  _performHold() async {
    _holdCall
      ? callDirections!.unhold()
      : callDirections!.hold();
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

  displayName(displayName) {
    return Text(
      displayName,
      style: TextStyle(color: whiteColor, fontFamily: "primaryFont", fontSize: headerSize * 1.35, fontWeight: FontWeight.w300),
      textAlign: TextAlign.center,
      maxLines: 2,
    );
  }

  displayRemoteIdentity(remoteIdentity) {
    return Text(
      remoteIdentity,
      style: TextStyle(color: whiteColor, fontFamily: "primaryFont", fontSize: headerSize * 1.35, fontWeight: FontWeight.w300),
      textAlign: TextAlign.center,
      maxLines: 2,
    ); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 20, 28, 52),
      body: !inProgress 
        ? Column(
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
                                  dialerStatus ? "Online ($extentionNo)"  : "Offline ($extentionNo)",
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
                              onPressed: () async {
                                if (destination.isNotEmpty) {
                                  _performCall(context, true);
                                  _existContact(username, destination);
                                  await Future.delayed(const Duration(seconds: 3));
                                  sfSearchRecordJS(callDirections!.remote_identity!, prioritySfSearchOrder, prioritySfForm.replaceAll(RegExp(r's$'), ''), allowInterop((String attributeType) {
                                    _registerCallGet(username, callDirections!.remote_identity!, extentionNo, 'inbound', objectType: attributeType);
                                  }));
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
                                  destinationName = '';
                                  destination = destination.substring(0, destination.length - 1);
                                  if (destination == destination) {
                                    destinationName = destinationName;
                                  }
                                });
                              } else {
                                destinationName = '';
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
                                setState(() => destination = '');
                              } else {
                                setState(() => _dialPad = false);
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
        : !_answered
          ? Column(
              children: [ 
                const SizedBox(height: 10,), 
                const Spacer(),
                displayName(callDirections!.remote_display_name!),
                displayRemoteIdentity(callDirections!.remote_identity!),
                const SizedBox(height: 50,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Transform.rotate(
                      angle: callDirections!.direction == Direction.incoming.name.toUpperCase() 
                        ? 0 
                        : 40.05,
                      child: AvatarGlow(
                        glowColor: callDirections!.direction == Direction.incoming.name.toUpperCase() 
                          ? primaryColor2 
                          : redColor,
                        child: CircleAvatar(
                          backgroundColor: callDirections!.direction == Direction.incoming.name.toUpperCase() 
                            ? primaryColor2 
                            : redColor,
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
                    Transform.rotate(
                      angle: 40.05,
                      child: CircleAvatar(
                        backgroundColor: redColor,
                        radius: headerSize * 1.8,
                        child: IconButton(
                          onPressed: () {
                            sfSearchRecordJS(callDirections!.remote_identity!, prioritySfSearchOrder, prioritySfForm.replaceAll(RegExp(r's$'), ''), allowInterop((String attributeType) {
                              _registerCallGet(username, callDirections!.remote_identity!, extentionNo, 'inbound', objectType: attributeType);
                            }));

                            _performHangup();
                          },
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
                  ],
                ),
                const Spacer()
              ], 
            )
          : Column(
              children: [
                const SizedBox(height: 10),
                displayLogo(context),
                const Spacer(),
                displayName(destinationName),
                displayRemoteIdentity(callDirections!.remote_identity!),
                const SizedBox(height: 20),
                StreamBuilder<int>(
                  stream: _stopWatchTimer.rawTime,
                  initialData: _stopWatchTimer.rawTime.value,
                  builder: (context, snapshot) {
                    final elapsedMilliseconds = snapshot.data ?? 0;
                    final displayTime = StopWatchTimer.getDisplayTime(
                      elapsedMilliseconds,
                      hours: elapsedMilliseconds >= 3600000,
                      milliSecond: false,
                    );
                    return Text(
                      displayTime,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey.shade200),
                    );
                  },
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_callState == CallStateEnum.CONFIRMED && _parkedCall == false) {
                                _performHold(); 
                              }
                            },
                            iconSize: headerSize * 2,
                            icon: _parkedCall
                              ? Icon(LucideIcons.pause, size: headerSize * 1.6, color: primaryColor2)
                              : Icon(
                                  LucideIcons.pause, size: headerSize * 1.6, 
                                  color: _holdCall 
                                    ? primaryColor2 
                                    : whiteColor
                                ),
                          ),
                          const SizedBox(height: 10, ),
                          Text(
                            "Hold",
                            style: _parkedCall
                              ? TextStyle(color: primaryColor2, fontSize: paragraphSize, fontWeight: FontWeight.w300)
                              : TextStyle(
                                  color: _holdCall 
                                    ? primaryColor2 
                                    : whiteColor, 
                                  fontSize: paragraphSize, 
                                  fontWeight: FontWeight.w300
                                ),
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
                            icon: Icon(
                              _muteCall 
                                ? LucideIcons.micOff 
                                : LucideIcons.mic, 
                              size: headerSize * 1.6, 
                              color: _muteCall 
                                ? primaryColor2 
                                : whiteColor
                            ),
                          ),
                          const SizedBox(height: 10, ),
                          Text(
                            "Mute",
                            style: TextStyle(
                              color: _muteCall 
                                ? primaryColor2 
                                : whiteColor, 
                              fontSize: paragraphSize, 
                              fontWeight: FontWeight.w300
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20,),
                Container(
                  color: Colors.white10,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: redColor,
                          child: InkWell(
                            onTap: _performHangup,
                            child: Icon(CarbonIcons.phone_filled, size: headerSize * 2, color: whiteColor, opticalSize: headerSize * 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void callStateChanged(Call call, CallState callState) async {
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

    switch (callState.state)  {
      case CallStateEnum.CALL_INITIATION:
        setState(() => callDirections = call);
        if (call.direction == "INCOMING") {
          sfToggleSoftphonePanelJS(true);

          _player.play(
            UrlSource('https://$ringqServer:8443/audio/ringtone2.mp3'), 
            mode: PlayerMode.lowLatency,
          );
        }
        if (call.direction == "OUTGOING") {
          setState(() => _answered = true);

          _player.play( 
            AssetSource('sounds/falsering.wav'),
            mode: PlayerMode.lowLatency,
          );
        }
        break;
      case CallStateEnum.PROGRESS:
        setState(() => inProgress = true );
        break;
      case CallStateEnum.STREAM:
        MediaStream? stream = callState.stream;
        if (callState.originator == "local") {
          if (_localRenderer != null) {
            _localRenderer!.srcObject = stream;
          }
          if (!kIsWeb && !WebRTC.platformIsDesktop) {
            callState.stream?.getAudioTracks().first.enableSpeakerphone(false);
          }
          _localStream = stream;
        }
        if (callState.originator == "remote") {
          if (_remoteRenderer != null) {
            _remoteRenderer!.srcObject = stream;
          }
          _remoteStream = stream;
        }
        break;
      case CallStateEnum.CONNECTING:
        break;
      case CallStateEnum.ACCEPTED:
        setState(() => _answered = true);
        _stopWatchTimer.onResetTimer();
        _stopWatchTimer.onStartTimer();
        _player.stop();
        break;
      case CallStateEnum.CONFIRMED:
        break;
      case CallStateEnum.MUTED: 
        break;
      case CallStateEnum.UNMUTED: 
        break;
      case CallStateEnum.HOLD:
        break;
      case CallStateEnum.UNHOLD:
        break;
      case CallStateEnum.ENDED:
        _clearStreams();
        setState(() {
          destination = '';
          inProgress = false;
          _answered = false;
          _muteCall = false;
          _holdCall = false;
        }); 
        _stopWatchTimer.onResetTimer();
        _player.stop(); 
        _localStream?.getTracks().forEach((track) {
          track.stop();
        });
        break; 
      case CallStateEnum.FAILED:
        _clearStreams(); 
        setState(() {
          destination = '';
          inProgress = false;
          _answered = false;
          _muteCall = false;  
          _holdCall = false;
        });
        _stopWatchTimer.onResetTimer();
        _player.stop(); 
        _localStream?.getTracks().forEach((track) {
          track.stop();
        });
        await Future.delayed(const Duration(seconds: 1));
        prettyLog('Faileedd');
        _registerCallGet(username, callDirections!.remote_identity!, extentionNo, 'misscall', objectType: entity);
        setState(() { entity = ''; });
        break;
      default:
    }
  }

  @override
  void registrationStateChanged(RegistrationState state) async {
    _player.play(
      UrlSource('https://$ringqServer:8443/audio/ringtone2.mp3'), 
      mode: PlayerMode.lowLatency,
    );
    _player.stop();

    setState(() {
      dialerStatus = true;
    });
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewReinvite(ReInvite event) {}

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
    sipUAHelper.removeSipUaHelperListener(this);
    _disposeRenderers();
  }
}  