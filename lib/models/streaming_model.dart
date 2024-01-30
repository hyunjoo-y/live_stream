import 'dart:convert';

class StreamingModel {
  List<int> thumbnail;
  String title;
  String roomName;

  StreamingModel({
    required this.thumbnail,
    required this.title,
    required this.roomName,
  });

  Map<String, dynamic> toMap() {
    return {'title': title, 'roomName': roomName};
  }

  String toJson() {
    return json.encode(toMap());
  }

  static StreamingModel fromMap(Map<String, dynamic> map) {
    return StreamingModel(
      roomName: map['roomName'],
      title: map['title'],
      thumbnail: (map['thumbnail'] as List<dynamic>).cast<int>(),
    );
  }

  static StreamingModel fromJson(String json) {
    return fromMap(jsonDecode(json));
  }
}