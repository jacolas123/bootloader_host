/* import 'dart:collection';
import 'dart:typed_data';

import 'package:libserialport/libserialport.dart';
import '../cybtldr_parse.dart';
import '../cybtldr_utils.dart';

class CyBtldr_CommunicationsData {
  late SerialPort port;
  Uint8List inData = Uint8List(MAX_BUFFER_SIZE);
  bool receivedData = false;
  int OpenConnection() {
    try {
      port = SerialPort("COM9");
      SerialPortConfig config = port.config;
      config.baudRate = 57600;
      config.bits = 8;
      config.cts = SerialPortCts.ignore;
      config.dsr = SerialPortDsr.ignore;
      config.dtr = SerialPortDtr.off;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.rts = SerialPortRts.off;
      config.xonXoff = SerialPortXonXoff.disabled;

      port.config = config;
      if (!port.openReadWrite()) {
        return 1;
      } else {
        final reader = SerialPortReader(port, timeout: 1000);
        reader.stream.listen(
          (data) {
            inData = data;
            receivedData = true;
          },
          onDone: () {
            bool isDone = true;
          },
        );
      }
    } catch (e) {
      return 1;
    }
    return CYRET_SUCCESS;
  }

  int CloseConnection() {
    port.close();
    //port.dispose();
    return CYRET_SUCCESS;
  }

  (int, Uint8List) ReadData(int size) {
    if (!receivedData) {
      return (1, Uint8List(0));
    } else {
      Uint8List toReturn = inData;
      receivedData = false;
      if (inData.length >= size) {
        return (CYRET_SUCCESS, toReturn.sublist(0, size));
      } else {
        return (CYRET_SUCCESS, toReturn);
      }
    }
  }

  int WriteData(Uint8List data, int length) {
    try {
      Uint8List toSend = Uint8List.fromList(data.getRange(0, length).toList());
      port.write(toSend, timeout: 0);
    } catch (e) {
      return 1;
    }
    return CYRET_SUCCESS;
  }

  bool hasData() {
    return receivedData;
  }

/* Value used to specify the maximum number of bytes that can be transfered at a time */
  int MaxTransferSize = 32;
}
 */