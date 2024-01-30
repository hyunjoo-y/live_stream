import 'package:flutter/services.dart';
import 'package:live_streaming/models/contract_model.dart';
import 'package:web3dart/web3dart.dart';

Future<DeployedContract> getContract(Contracts smartContract) async {
  String abiFile = await rootBundle.loadString(smartContract.abiJson);
  final contract = DeployedContract(
      ContractAbi.fromJson(abiFile, smartContract.contractName),
      EthereumAddress.fromHex(smartContract.contractAddress));

  return contract;
}

Future<List<dynamic>> callFunction(
    Contracts smartContract, String functionName) async {
  final contract = await getContract(smartContract);
  final function = contract.function(functionName);
  /*String foo = 'relay';
  List<int> bytsList = utf8.encode(foo);*/

  final result = await smartContract.client
      .call(contract: contract, function: function, params: []);
  return result;
}

Future<List<String>> getStreaming(Contracts smartContract) async {
  final contract = await getContract(smartContract);
  final function = contract.function("getStreaming");

  Stopwatch stopwatch = Stopwatch()..start();
  final result = await smartContract.client
      .call(contract: contract, function: function, params: []);
  print("test ${result[0]}");
  stopwatch.stop(); // 스톱워치 정지
  double milliseconds = stopwatch.elapsed.inMicroseconds / 1000.0;
  print('블록체인 호출 (밀리초): $milliseconds ms');

  // 결과를 List<String>으로 변환하여 반환
  return (result[0] as List<dynamic>).map((item) => item.toString()).toList();
}

Future<bool?> setStreaming(Contracts smartContract, String hashValue) async {
  try {
    Credentials key = EthPrivateKey.fromHex(smartContract.privateKey);

    // Obtain our contract from ABI in JSON file
    final contract = await getContract(smartContract);
    final function = contract.function("setStreaming");
    print('Function obtained: $function');

    // Estimate gas for the transaction
    final gasEstimate = await smartContract.client.estimateGas(
      sender: key.address,
      to: contract.address,
      data: function.encodeCall([hashValue]),
    );
    print('Estimated gas: $gasEstimate');

    // Send transaction
    final result = await smartContract.client.sendTransaction(
      key,
      Transaction.callContract(
        contract: contract,
        function: function,
        parameters: [hashValue],
        gasPrice: EtherAmount.inWei(BigInt.parse('20000000000')), // Set appropriate gas price
        maxGas: gasEstimate.toInt(), // Use estimated gas
      ),
      chainId: 1241,
    );

    print('Transaction result: $result');

    return result.isNotEmpty;
  } catch (e) {
    print('Error setting streaming: $e');
    return false;
  }
}

