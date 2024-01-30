import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:http/http.dart' as http;
import 'package:live_streaming/models/contract_model.dart';
import 'package:live_streaming/models/streaming_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:web3dart/web3dart.dart';

class StreamingRoom extends StatefulWidget {
  const StreamingRoom({
    Key? key,
    required this.isPub,
    required this.nodeId,
    required this.streamHash,
  }) : super(key: key);
  final bool isPub;
  final String nodeId;
  final String streamHash;
  @override
  State<StreamingRoom> createState() => _StreamingRoomState();
}

class _StreamingRoomState extends State<StreamingRoom> {
  late RTCDataChannel _dataChannel;
  String roomId = "";

  late http.Client httpClient;
  late Web3Client ethClient;
  late Contracts contract;

  final String blockchainUrl = "http://115.85.181.212:30011";
  final String contractAddress = "0xD6DcbF990DE278ec3f151098D5505C678b30A70A";
  //final String contractAddress = "0x174a06033F9a61Df6716bd4Dc09c1806Ba80251f";
  final String priv =
      "778f4905fcee27222ef12e05885d5edf740a5bf2881e4340c9379a4cf99c711c";

  late IO.Socket newSocket;

  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  MediaStream? _localStream;

  RTCPeerConnection? pc;
  List<StreamingModel> streamingModels = [];

  var startTime;

  @override
  void initState() {
    initRender();
    initWebRTC();
    super.initState();
    httpClient = http.Client();
    ethClient = Web3Client(blockchainUrl, httpClient);
    contract = Contracts(
        client: ethClient,
        abiJson: 'assets/stream_sdk.json',
        contractAddress: contractAddress,
        contractName: "StreamingContract",
        privateKey: priv);
  }

  @override
  void dispose() {
    // 위젯이 제거될 때 리소스 정리
    leaveRoom();
    super.dispose();
  }

  Future<void> leaveRoom() async {
    // MediaStream 종료
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        track.stop();
      });
      _localStream!.dispose();
      _localStream = null;
    }

    // PeerConnection 종료
    if (pc != null) {
      pc!.close();
      pc = null;
    }

    // Renderer 종료
    if (_localRenderer != null) {
      _localRenderer!.dispose();
      _localRenderer = null;
    }

    if (_remoteRenderer != null) {
      _remoteRenderer!.dispose();
      _remoteRenderer = null;
    }

    // 상태 업데이트 (옵션)
    setState(() {});
  }

  initRender() async {
    _localRenderer = RTCVideoRenderer(); // Initialize _localRenderer
    _remoteRenderer = RTCVideoRenderer(); // Initialize _remoteRenderer

    await _localRenderer?.initialize();
    await _remoteRenderer?.initialize();
  }

  Future<void> initWebRTC() async {
    await connectSocket();
    await checkAndRequestPermissions();
    setState(() {});
  }

  Future connectSocket() async {
    try {

     startTime = DateTime.now();
      newSocket = IO.io(
        "http://54.180.79.59:30006",
        IO.OptionBuilder().setTransports(['websocket']).build(),
      );

      newSocket.onConnect((data) {
        print('connect!');
      });

      initializeSocketListeners();
    } catch (error) {
      print('Socket 연결 실패: $error');
    }
  }

  void initializeSocketListeners() {
    newSocket.on('joined', (data) {
      print(': socket--joined / $data');
      onReceiveJoined();
    });

    newSocket.on('offer', (data) {
      print(': listener--offer');
      onReceiveOffer(jsonDecode(data));
    });

    newSocket.on('answer', (data) {
      print(' : socket--answer');
      onReceiveAnswer(jsonDecode(data));
    });

    newSocket.on('ice', (data) {
      print(': socket--ice');
      onReceiveIce(jsonDecode(data));
    });
  }

  Future<void> checkAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera]!.isDenied ||
        statuses[Permission.microphone]!.isDenied) {
      // 사용자가 권한을 거부한 경우 처리
      // 권한이 필요한 이유를 사용자에게 설명하거나 설정으로 이동하도록 안내
    } else {
      // 권한이 허용된 경우 joinRoom() 함수 호출
      await joinRoom();
      setState(() {});
    }
  }

  Future joinRoom() async {
    final config = {
      'iceServers': [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final sdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': []
    };

    pc = await createPeerConnection(config, sdpConstraints);
    // 카메라
    final mediaConstraints = {
      'audio': true,
      'video': {'facingMode': 'facingMode'}
    };

    _localStream = await Helper.openCamera(mediaConstraints);

    _localStream!.getTracks().forEach((track) {
      pc!.addTrack(track, _localStream!);
    });

    _localRenderer?.srcObject = _localStream;

    pc!.onIceCandidate = (ice) {
      // ice 를 상대방에게 전송
      onIceGenerated(ice);
    };

    pc!.onDataChannel = (channel) {
      _addDataChannel(channel);
    };
    pc!.onAddStream = (stream) {
      var endTime = DateTime.now();
      var totalDuration = endTime.difference(startTime).inMilliseconds;

    print('총 연결 시간: $totalDuration ms');
      _remoteRenderer?.srcObject = stream;
    };

    // join --> node id, hash 값 전송
   //newSocket.emit('join');

    if (widget.isPub) {
      var streamInfo = {
        'nodeId': widget.nodeId,
        'streamHash': widget.streamHash
      };

      newSocket.emit('setStream', streamInfo);
      var setEndTime = DateTime.now();
      var totalDuration = setEndTime.difference(startTime).inMilliseconds;

    print('총 연결 시간: $totalDuration ms');
    } else {
      newSocket.emit('checkNode', widget.nodeId);
    }
  }

  void onReceiveJoined() {
    _sendOffer();
  }

  Future _sendOffer() async {
    RTCSessionDescription offer = await pc!.createOffer();
    pc!.setLocalDescription(offer);

    newSocket.emit('offer', jsonEncode(offer.toMap()));
  }

  Future<void> _createDataChannel() async {
    RTCDataChannelInit dataChannelDict = new RTCDataChannelInit();
    RTCDataChannel? channel = await pc?.createDataChannel("1", dataChannelDict);

    _addDataChannel(channel!);
  }

  void _addDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;

    _dataChannel.onMessage = (data) async {
      print('message ${data.text}');
    };

    _dataChannel.onDataChannelState = (state) {
      // state.toString();
      print(state.toString());
    };
  }

  Future<void> onReceiveOffer(data) async {
    final offer = RTCSessionDescription(data['sdp'], data['type']);
    pc!.setRemoteDescription(offer);

    final answer = await pc!.createAnswer();
    pc!.setLocalDescription(answer);

    _sendAnswer(answer);
  }

  Future _sendAnswer(answer) async {
    newSocket.emit('answer', jsonEncode(answer.toMap()));
  }

  Future onReceiveAnswer(data) async {
    setState(() {});
    final answer = RTCSessionDescription(data['sdp'], data['type']);
    pc!.setRemoteDescription(answer);
  }

  Future onIceGenerated(RTCIceCandidate ice) async {
    setState(() {});

    newSocket.emit('ice', jsonEncode(ice.toMap()));
  }

  Future onReceiveIce(data) async {
    setState(() {});

    final ice = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
    pc!.addCandidate(ice);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isPub && _localRenderer != null)
          Expanded(
            child: RTCVideoView(_localRenderer!),
          ),
        if (!widget.isPub && _remoteRenderer != null)
          Expanded(
            child: RTCVideoView(_remoteRenderer!),
          ),
        // 화면에 아무것도 표시되지 않을 때 대체 위젯을 표시합니다.
        if (_localRenderer == null && _remoteRenderer == null)
          Expanded(
            child: Center(child: Text("Waiting for the video...")),
          ),
      ],
    );
  }
}
