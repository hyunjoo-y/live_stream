import 'package:web3dart/web3dart.dart';

class Contracts {
  Web3Client client;
  String abiJson;
  String contractAddress;
  String contractName;
  String privateKey;

  Contracts({required this.client, required this.abiJson, required this.contractAddress, required this.contractName, required this.privateKey});

  Map<String, dynamic> toMap() {
    return {'abiJson': abiJson, 'contractAddress': contractAddress, 'contractName': contractName, 'privateKey': privateKey};
  }
}