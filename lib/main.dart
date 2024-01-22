import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _offer = false;
  RTCPeerConnection? _peerConnection;
  late MediaStream  _localStream;
  var _localRender = RTCVideoRenderer();
  final _remoteRender = RTCVideoRenderer();
  final sdpController = TextEditingController();

  @override
  void initState(){
    initRender();
    _getUderMedia();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    super.initState();

  }
  _createPeerConnection() async {
    Map<String,dynamic> configuration = {
      "iceServers": [
        {"url" : "stun:stun.l.google.com:19302"},
      ]
    };
    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferTOReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUderMedia();

    RTCPeerConnection pc = await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(_localStream);

    pc.onIceCandidate = (e) {
      if(e.candidate != null) {
        print(jsonEncode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMLineIndex
        }));
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ${stream.id}');
      _remoteRender.srcObject = stream;
    };

    return pc;
  }
  Future<void> initRender() async {
    await _localRender.initialize();
    await _remoteRender.initialize();
  }

  _getUderMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user'
      }
    };

    MediaStream stream  = await navigator.getUserMedia(mediaConstraints);
    _localRender.srcObject = stream;
    _localRender.muted = true;
    return stream;
  }


  @override
  void dispose() {
    // TODO: implement dispose
    _localRender.dispose();
    _remoteRender.dispose();
    sdpController.dispose();
    super.dispose();
  }


  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Container(
        child: Column(
          children: [
            videoRenderers(),
            offerAndAnswerButtons(),
            sdpCandiateTF(),
            sdpCandidateButtons()
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
  
  videoRenderers() {

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Flexible(
            child: Container(
              key: Key('local'),
              margin: EdgeInsets.fromLTRB(5, 5, 5, 5),
              decoration: BoxDecoration(
                color: Colors.black
              ),
              child: RTCVideoView(_localRender),
            )
          ),
          Flexible(
            child: Container(
              key: Key('remote'),
              margin: EdgeInsets.fromLTRB(5, 5, 5, 5),
              decoration: BoxDecoration(
                color: Colors.black
              ),
              child: RTCVideoView(_remoteRender),
            )
          ),
        ],
      ),
    );
  }
  
  offerAndAnswerButtons() {

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () async {
            RTCSessionDescription description = await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
            var session = parse(description.sdp as String);
            print(jsonEncode(session));
            _offer = true;

            _peerConnection!.setLocalDescription(description);
          }, 
          child: Text("Offer"),
          style: const ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(
              Colors.blueAccent
            )
          ),
        ),
        TextButton(
          onPressed: () async {
            RTCSessionDescription description = await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});
            
            var session = parse(description.sdp as String);
            print(jsonEncode(session));
            _peerConnection!.setLocalDescription(description);
          }, 
          child: Text("Answer"),
          style: const ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(
              Colors.blueAccent
            )
          ),
        ),
      ],
    );
  }
  
  sdpCandiateTF() {

    return Padding(
      padding:  EdgeInsets.all(8.0),
      child: TextField(
        controller: sdpController,
        keyboardType: TextInputType.multiline,
        maxLines: 4,
        maxLength: TextField.noMaxLength,
      ),
    );
  }
  
  sdpCandidateButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () async {
            String jsonString = sdpController.text;
            dynamic session = await jsonDecode('$jsonString');
            String sdp = write(session, null);
            RTCSessionDescription description = 
            RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
            print(description.toMap());
            await _peerConnection!.setRemoteDescription(description);
          }, 
          child: Text("Set remote")),
        TextButton(
          onPressed: () async {
            String jsonString = sdpController.text;
            dynamic session = await jsonDecode('$jsonString');
            print(session['candidate']);
            dynamic candidate = new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMLineIndex']);
            await _peerConnection!.addCandidate(candidate);
            
          }, 
          child: Text("Set candiate")),
      ],
    );
  }
  
  
}


