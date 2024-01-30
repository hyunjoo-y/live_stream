import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:live_streaming/components/cocnstat.dart';
import 'package:live_streaming/models/contract_model.dart';
import 'package:live_streaming/screens/follow_page.dart';
import 'package:live_streaming/screens/live_page.dart';
import 'package:live_streaming/screens/profile_page.dart';
import 'package:live_streaming/screens/streaming_room_page.dart';
import 'package:live_streaming/sdk/contract_sdk.dart';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController tabController;
  int currentTabIndex = 0;
  static const List<Widget> movePage = <Widget>[
    LiveStreamingPage(),
    FollowPage(),
    ProfilePage()
  ];

  late http.Client httpClient;
  late Web3Client ethClient;
  late Contracts contract;

  final String blockchainUrl = "http://115.85.181.212:30011";
  final String contractAddress = "0xD6DcbF990DE278ec3f151098D5505C678b30A70A";
  //final String contractAddress = "0x174a06033F9a61Df6716bd4Dc09c1806Ba80251f";
  final String priv =
      "778f4905fcee27222ef12e05885d5edf740a5bf2881e4340c9379a4cf99c711c";
  late String streamHash = "";

  @override
  void initState() {
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

  Future<List<int>> getImageBytes(String imagePath) async {
    final ByteData imageData = await rootBundle.load(imagePath);
    return imageData.buffer.asUint8List();
  }

  Future<void> _saveStreamingInfo() async {
    var startTime = DateTime.now();

    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory.path}/streaming_info.json');

    var base64ImageData = await getImageBytes('assets/logo.png');
    final imageData = base64Encode(base64ImageData);

    final data = {
      'imageData': imageData,
      'title': 'Show Me!',
      'roomName': 'Alice'
    };

    final jsonString = json.encode(data);
    await file.writeAsString(jsonString);

    String credentials =
        "2ONnXhK5E0OyIEBTFsaZVRB5Agj:bba5e99a4c2228f58f06bd70af022106";
    Codec<String, String> stringToBase64 = utf8.fuse(base64);
    String encoded = stringToBase64.encode(credentials);
    streamHash = await uploadFileToIPFS(file, encoded);
    var afterIPFS = DateTime.now();

    // 자신의 컨트랙트 콘텐츠 리스트에 해시값 기록
    //bool? reCheck = await setStreaming(contract, streamHash);

    var endTime = DateTime.now();
    // 각 단계별 시간 측정
    var ipfsDuration = afterIPFS.difference(startTime).inMilliseconds;
   // var blockchainDuration = endTime.difference(afterIPFS).inMilliseconds;
    var totalDuration = endTime.difference(startTime).inMilliseconds;

    // 콘솔에 결과 출력
    print('IPFS 업로드 시간: $ipfsDuration ms');
   // print('블록체인 기록 시간: $blockchainDuration ms');
    print('총 소요 시간: $totalDuration ms');

    print('hash $streamHash');
    //print('Data saved to ${reCheck}');
  }

  Future<String> uploadFileToIPFS(File file, String token) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://ipfs.infura.io:5001/api/v0/add'),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
      ),
    );

    request.headers['Authorization'] = 'Basic $token';

    var response = await request.send();

    var responseBody = await response.stream.bytesToString();
    var jsonResponse = json.decode(responseBody);

    if (jsonResponse.containsKey('Hash')) {
      print('all ${jsonResponse.toString()}');
      return jsonResponse['Hash'];
    } else {
      throw Exception('Failed to upload file to IPFS');
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime? _lastPressedAt;
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      bottomNavigationBar: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: GNav(
              backgroundColor: Colors.black,
              color: Colors.white,
              activeColor: Colors.white,
              tabBackgroundColor: Colors.grey.shade800,
              gap: 8,
              padding: EdgeInsets.all(16),
              onTabChange: (index) {
                setState(() {
                  currentTabIndex = index;
                });
              },
              tabs: const [
                GButton(
                  icon: Icons.home,
                  text: 'HOME',
                ),
                GButton(
                  icon: Icons.star,
                  text: 'FOLLOW',
                ),
                GButton(icon: Icons.person, text: 'PROFILE'),
              ]),
        ),
      ),
      backgroundColor: Colors.black87,
      body: WillPopScope(
        onWillPop: () async {
          if (_lastPressedAt == null ||
              DateTime.now().difference(_lastPressedAt!) >
                  Duration(seconds: 2)) {
            // 첫 번째 뒤로가기 버튼 클릭 시
            _lastPressedAt = DateTime.now();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                backgroundColor: Colors.grey,
                content: const Text('한 번 더 누르시면 종료됩니다.'),
                duration: Duration(seconds: 2),
              ),
            );
            return false;
          } else {
            // 두 번째 뒤로가기 버튼 클릭 시
            SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            return true; // 앱 종료
          }
        },
        child: Column(
          children: [movePage.elementAt(currentTabIndex)],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: mainColor,
        onPressed: () {
          setState(() async {
            if (currentTabIndex == 0) {
              await _saveStreamingInfo();
              // ignore: use_build_context_synchronously
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StreamingRoom(
                    isPub: true,
                    streamHash: streamHash,
                    nodeId: 'Alice',
                  ),
                ),
              );
            } else if (currentTabIndex == 1) {
              setState(() {});
            } else {}
          });
        },
        child: Icon(currentTabIndex == 0
            ? Icons.video_call
            : currentTabIndex == 1
                ? Icons.message_rounded
                : Icons.settings),
      ),
    );
  }
}
