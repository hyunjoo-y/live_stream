import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:live_streaming/models/contract_model.dart';
import 'package:live_streaming/sdk/contract_sdk.dart';
import 'package:live_streaming/models/streaming_model.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:live_streaming/screens/streaming_room_page.dart';
import 'package:web3dart/web3dart.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LiveStreamingPage extends StatefulWidget {
  const LiveStreamingPage({super.key});

  @override
  State<LiveStreamingPage> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage> {
  late IO.Socket newSocket;
  List<StreamingModel> streamingModels = [];
  late http.Client httpClient;
  late Web3Client ethClient;
  late Contracts contract;

  final String blockchainUrl = "http://IP_address";
  final String contractAddress = "0x...";
  //final String contractAddress = "0x...";
  final String priv =
      "private_key";
  Map<String, dynamic> streamData = {};
  var startTime;

  @override
  void initState() {
    httpClient = http.Client();
    ethClient = Web3Client(blockchainUrl, httpClient);
    contract = Contracts(
        client: ethClient,
        abiJson: 'assets/stream_sdk.json',
        contractAddress: contractAddress,
        contractName: "StreamingContract",
        privateKey: priv);

    super.initState();
    callLive();

    //
    //initWebRTC();
  }

  @override
  void dispose() {
    newSocket.destroy();
    super.dispose();
  }

  Future<void> callLive() async {
    await connectSocket();
    await downloadFilesFromIPFS();
  }

  Future<void> connectSocket() async {
    Completer<void> completer = Completer();

    try {
      startTime = DateTime.now();
      newSocket = IO.io(
        "http://IP-address",
        IO.OptionBuilder().setTransports(['websocket']).build(),
      );

      newSocket.onConnect((_) {
        print('connect!');
        newSocket.emit('getStream');
      });

      newSocket.onDisconnect((data) {
        print('disconnect!');

        // 서버 소켓 연결이 끊겼을 때 다른 주소로 재연결
        connectToNewServer();
      });


      newSocket.on('streamArr', (data) {
        var endTime = DateTime.now();
        var totalDuration = endTime.difference(startTime).inMilliseconds;

        print('릴레이한테 목록 시간 받아오기: $totalDuration ms');

        print(': socket--getStream /$data');

        setState(() {
          streamData = Map<String, dynamic>.from(data);
        });

        print('data: $streamData');
        //newSocket.disconnect();
        completer.complete(); // 소켓 수신 완료 시점에 completer를 완료 상태로 설정
      });
    } catch (error) {
      print('Socket 연결 실패: $error');
      completer.completeError(error);
    }

    return completer.future; // 이 Future는 streamArr 이벤트 수신 완료까지 기다림
  }

  void connectToNewServer() {
  // 새로운 서버 주소를 설정
  String newServerAddress = "http://IP_address";

  newSocket = IO.io(
    newServerAddress,
    IO.OptionBuilder().setTransports(['websocket']).build(),
  );

  newSocket.onConnect((data) {
    print('connect!');
  });

}


  // streamData 변수를 사용하여 IPFS에서 파일을 다운로드
  Future<List<StreamingModel>> downloadFilesFromIPFS() async {
    var startTime = DateTime.now();

    for (var entry in streamData.entries) {
      String nodeId = entry.key;
      String streamHash = entry.value;

      final url = 'https://testmessenger.infura-ipfs.io/ipfs/$streamHash';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var endTime = DateTime.now();
        var totalDuration = endTime.difference(startTime).inMilliseconds;

        print('IPFS 다운 시간: $totalDuration ms');

        final responseBody = response.body;
        final jsonMap = json.decode(responseBody);

        final roomName = jsonMap['roomName'];
        final title = jsonMap['title'];
        final encodedImageData = jsonMap['imageData'];

        final imageData = base64Decode(encodedImageData);

        StreamingModel streamObject = StreamingModel(
          thumbnail: imageData,
          title: title,
          roomName: roomName,
        );
        setState(() {
          streamingModels.add(streamObject);
        });
      } else {
        print(
            'Failed to download file from IPFS for stream hash: $streamHash. Status code: ${response.statusCode}');
      }
    }

    return streamingModels;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Set the crossAxisAlignment to start
        children: <Widget>[
          SizedBox(height: size.height * 0.1),
          Padding(
            // Updated to Padding widget for simplicity
            padding: EdgeInsets.only(left: size.width * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment
                  .start, // Set the crossAxisAlignment to start
              children: [
                Text(
                  'Discover',
                  style: GoogleFonts.abel(
                      fontWeight: FontWeight.w800,
                      fontSize: 25,
                      color: Colors.white),
                ),
                Text(
                  'Find your favorite streamers',
                  style: GoogleFonts.abel(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                SizedBox(
                  height: size.height * 0.05,
                ),
                Center(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: size.width * 0.05),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search streamers",
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: size.height * 0.03,
                    ),
                    Text(
                      'LIVE',
                      style: GoogleFonts.abel(
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        color: Colors.red,
                      ),
                    ),
                    ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: streamingModels.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 5.0, horizontal: 16.0),
                            elevation: 5, // Adds shadow under the card
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              contentPadding: EdgeInsets.only(
                                  left: size.width * 0.03, right: 16.0),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    10), // Rounded corners for the image
                                child: Image(
                                  image: MemoryImage(Uint8List.fromList(
                                      streamingModels[index].thumbnail)),
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              ),
                              title: Text(
                                streamingModels[index].title,
                                style: GoogleFonts.abel(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: Colors.black),
                              ),
                              subtitle: Text(
                                streamingModels[index].roomName,
                                style: GoogleFonts.abel(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Colors.grey
                                      .shade700, // Slightly lighter color for the subtitle
                                ),
                              ),
                              trailing: const Icon(Icons.live_tv,
                                  color: Colors
                                      .red), // Icon to indicate live status
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StreamingRoom(
                                      isPub: false,
                                      nodeId: streamingModels[index].roomName,
                                      streamHash: '',
                                    ),
                                  ),
                                );
                                // Handle tap
                              },
                            ),
                          );
                        }),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
