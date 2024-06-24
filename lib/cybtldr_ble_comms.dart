// ignore_for_file: camel_case_types, non_constant_identifier_names

import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'cybtldr_parse.dart';

import 'cybtldr_utils.dart';

class CyBtldr_CommunicationsData {
  Uint8List inData = Uint8List(MAX_BUFFER_SIZE);
  late BluetoothDevice device;
  late BluetoothCharacteristic txChar;
  late BluetoothCharacteristic modemOutChar;
  late BluetoothCharacteristic modemInChar;
  bool receivedData = false;
  bool canSendData = true;
  bool written = false;
  int inDataCurrentPosition = 0;

  void SetDevice(BluetoothDevice inDevice) {
    device = inDevice;
  }

  Future<int> OpenConnection() async {
    try {
      if (device.isConnected) {
        //await device.createBond();
        var services = await device.discoverServices();
        if (services.isNotEmpty) {
          var service = services
              .singleWhere((element) => element.uuid == UartServiceGuid);
          var rxChar = service.characteristics
              .singleWhere((element) => element.uuid == RxFiFoCharGuid);

          await rxChar.setNotifyValue(rxChar.isNotifying == false);

          rxChar.onValueReceived.listen((value) {
            for (int i in value) {
              inData[inDataCurrentPosition] = i;
              inDataCurrentPosition = inDataCurrentPosition + 1;
            }
          });
          var modemOutChar = service.characteristics
              .singleWhere((element) => element.uuid == ModemOutGuid);
          await modemOutChar.setNotifyValue(true);
          modemOutChar.onValueReceived.listen((value) {
            canSendData = value.first == 1;
          });

          var modemInChar = service.characteristics
              .singleWhere((element) => element.uuid == ModemInGuid);
          if (modemInChar.properties.write) {
            await modemInChar.write([1]);
          }

          txChar = service.characteristics
              .singleWhere((element) => element.uuid == TxFiFoCharGuid);

          return CYRET_SUCCESS;
        } else {
          return CYRET_ERR_DEVICE;
        }
      } else {
        return CYRET_ERR_DEVICE;
      }
    } catch (e) {
      return CYRET_ERR_DEVICE;
    }
  }

  int CloseConnection() {
    return CYRET_SUCCESS;
  }

  (bool, int, Uint8List) ReadData(int size) {
    if (inDataCurrentPosition != size) {
      if (inDataCurrentPosition % size != 0) {
        return (false, 1, Uint8List(0));
      } else {
        inDataCurrentPosition = size;
      }
    }
    Uint8List toReturn = inData;
    receivedData = false;
    if (inData.length >= size) {
      return (true, CYRET_SUCCESS, toReturn.sublist(0, size));
    } else {
      return (true, CYRET_SUCCESS, toReturn);
    }
  }

  Future<int> WriteData(Uint8List data, int length) async {
    try {
      Uint8List toSend = Uint8List.fromList(data.getRange(0, length).toList());
      inDataCurrentPosition = 0;
      await txChar
          .write(List.from(toSend))
          .timeout(const Duration(seconds: 10));
      //port.write(toSend, timeout: 0);
    } catch (e) {
      return 1;
    }
    return CYRET_SUCCESS;
  }

  bool hasData() {
    return receivedData;
  }

  Future<bool> canSend() async {
    List<int> readData = await modemOutChar.read();
    if (readData.isNotEmpty) {
      if (readData[0] == 1) {
        return true;
      }
    }
    return false;
  }

/* Value used to specify the maximum number of bytes that can be transfered at a time */
  int MaxTransferSize = 64;

  Guid UartServiceGuid = Guid("569a1101-b87f-490c-92cb-11ba5ea5167c");
  Guid RxFiFoCharGuid = Guid("569a2000-b87f-490c-92cb-11ba5ea5167c");
  Guid TxFiFoCharGuid = Guid("569a2001-b87f-490c-92cb-11ba5ea5167c");
  Guid ModemInGuid = Guid("569a2003-b87f-490c-92cb-11ba5ea5167c");
  Guid ModemOutGuid = Guid("569a2002-b87f-490c-92cb-11ba5ea5167c");
}
