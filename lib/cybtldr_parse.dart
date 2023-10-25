import 'dart:io';
import 'dart:typed_data';
import 'cybtldr_utils.dart';

int MAX_BUFFER_SIZE = 768;

List<String> dataFileData = <String>[];

String dataFilePath = "";

int parse2ByteValueBigEndian(Uint8List buf) {
  return ((buf[0] << 8)) | (buf[1]);
}

int parse4ByteValueBigEndian(Uint8List buf) {
  return ((parse2ByteValueBigEndian(buf)) << 16) |
      (parse2ByteValueBigEndian(
          Uint8List.fromList(buf.getRange(2, 4).toList())));
}

int parse2ByteValueLittleEndian(Uint8List buf) {
  return (buf[0]) | ((buf[1]) << 8);
}

int parse4ByteValueLittleEndian(Uint8List buf) {
  return (parse2ByteValueLittleEndian(buf)) |
      ((parse2ByteValueLittleEndian(
              Uint8List.fromList(buf.getRange(2, 4).toList()))) <<
          16);
}

int CyBtldr_FromHex(int value) {
  if ('0'.codeUnitAt(0) <= value && value <= '9'.codeUnitAt(0)) {
    return (value - '0'.codeUnitAt(0));
  }
  if ('a'.codeUnitAt(0) <= value && value <= 'f'.codeUnitAt(0)) {
    return (10 + value - 'a'.codeUnitAt(0));
  }
  if ('A'.codeUnitAt(0) <= value && value <= 'F'.codeUnitAt(0)) {
    return (10 + value - 'A'.codeUnitAt(0));
  }
  return 0;
}

(int, Uint8List, int) CyBtldr_FromAscii(int bufSize, Uint8List buffer) {
  int i;
  int rowSize = 0;
  Uint8List hexData = Uint8List(MAX_BUFFER_SIZE);
  int err = CYRET_SUCCESS;

  if ((bufSize & 1) == 1) // Make sure even number of bytes
  {
    err = CYRET_ERR_LENGTH;
  } else {
    for (i = 0; i < bufSize / 2; i++) {
      hexData[i] =
          (int.parse(String.fromCharCode(buffer[i * 2]), radix: 16) << 4) |
              int.parse(String.fromCharCode(buffer[i * 2 + 1]), radix: 16);
    }
    rowSize = i;
  }

  return (err, hexData, rowSize);
}

(int, String, int) CyBtldr_ReadLine(int lineIndex) {
  int err = CYRET_SUCCESS;
  bool lineFound = false;
  String toReturn = "";
  // line that start with '#' are assumed to be comments, continue reading if we read a comment

  while (!lineFound) {
    if (dataFileData.isNotEmpty) {
      if (lineIndex < dataFileData.length) {
        if (dataFileData[lineIndex][0] != '#') {
          int strLen = dataFileData[lineIndex].length;
          toReturn = dataFileData[lineIndex];
          if (toReturn[strLen - 1] == '\n' && toReturn[strLen - 2] == '\r') {
            toReturn = toReturn.substring(0, strLen - 2);
          }
          lineFound = true;
        } else {
          lineIndex++;
        }
      } else {
        err = CYRET_ERR_EOF;
        lineFound = true;
      }
    } else {
      err = CYRET_ERR_FILE;
      lineFound = true;
    }
  }
  return (err, toReturn, toReturn.length);
}

Future<int> CyBtldr_OpenDataFile(File file) async {
  try {
    await file.open();
  } catch (e) {
    return CYRET_ERR_FILE;
  }
  dataFileData = await file.readAsLines();
  return CYRET_SUCCESS;
}

(int, int) CyBtldr_ParseCyacdFileVersion(
    String fileName, int bufSize, Uint8List header) {
  // check file extension of the file, if extension is cyacd, version 0
  int index = fileName.length;
  int err = CYRET_SUCCESS;

  int version = 0;
  if (bufSize == 0) {
    err = CYRET_ERR_FILE;
  }
  while (CYRET_SUCCESS == err && fileName[--index] != '.') {
    if (index == 0) {
      err = CYRET_ERR_FILE;
    }
  }
  if (fileName.substring(index).toLowerCase() == ".cyacd2") {
    if (bufSize < 2) {
      err = CYRET_ERR_FILE;
    }
    // .cyacd2 file stores version information in the first byte of the file header.
    if (CYRET_SUCCESS == err) {
      version = CyBtldr_FromHex(header[0]) << 4 | CyBtldr_FromHex(header[1]);
      if (version == 0) {
        err = CYRET_ERR_DATA;
      }
    }
  } else if (fileName.substring(index).toLowerCase() == ".cyacd") {
    // .cyacd file does not contain version information
    version = 0;
  } else {
    err = CYRET_ERR_FILE;
  }
  return (err, version);
}

(int, int, int, int) CyBtldr_ParseHeader(int bufSize, Uint8List buffer) {
  int err = CYRET_SUCCESS;
  int chksum = 0;
  int siliconId = 0;
  int siliconRev = 0;
  int rowSize = 0;
  Uint8List rowData = Uint8List(MAX_BUFFER_SIZE);
  if (CYRET_SUCCESS == err) {
    (err, rowData, rowSize) = CyBtldr_FromAscii(bufSize, buffer);
  }
  if (CYRET_SUCCESS == err) {
    if (rowSize > 5) {
      chksum = rowData[5];
    } else {
      chksum = 0;
    }
    if (rowSize > 4) {
      siliconId = parse4ByteValueBigEndian(rowData);
      siliconRev = rowData[4];
    } else {
      err = CYRET_ERR_LENGTH;
    }
  }
  return (err, siliconId, siliconRev, chksum);
}

(int, int, int, int, int, int) CyBtldr_ParseHeader_v1(
    int bufSize, Uint8List buffer) {
  int err = CYRET_SUCCESS;
  int siliconId = 0;
  int siliconRev = 0;
  int chksum = 0;
  int appID = 0;
  int productID = 0;

  int rowSize = 0;
  Uint8List rowData = Uint8List(MAX_BUFFER_SIZE);
  if (CYRET_SUCCESS == err) {
    (err, rowData, rowSize) = CyBtldr_FromAscii(bufSize, buffer);
  }
  if (CYRET_SUCCESS == err) {
    if (rowSize == 12) {
      siliconId = parse4ByteValueLittleEndian(
          Uint8List.fromList(rowData.getRange(1, 5).toList()));
      siliconRev = rowData[5];
      chksum = rowData[6];
      appID = rowData[7];
      productID = parse4ByteValueLittleEndian(
          Uint8List.fromList(rowData.getRange(8, 13).toList()));
    } else {
      err = CYRET_ERR_LENGTH;
    }
  }
  return (err, siliconId, siliconRev, chksum, appID, productID);
}

(int, int, int, Uint8List, int, int) CyBtldr_ParseRowData(
    int bufSize, Uint8List buffer) {
  const int MIN_SIZE = 6; //1-array, 2-addr, 2-size, 1-checksum
  const int DATA_OFFSET = 5;

  int i;
  int err = CYRET_SUCCESS;
  int rowNum = 0;
  int arrayId = 0;
  int size = 0;
  int checksum = 0;
  Uint8List rowData = Uint8List(MAX_BUFFER_SIZE);

  if (bufSize <= MIN_SIZE) {
    err = CYRET_ERR_LENGTH;
  } else if (buffer[0] == ':'.codeUnitAt(0)) {
    var (err, hexData, hexSize) = CyBtldr_FromAscii(bufSize - 1,
        Uint8List.fromList(buffer.getRange(1, buffer.length).toList()));

    if (err == CYRET_SUCCESS) {
      arrayId = hexData[0];
      rowNum = parse2ByteValueBigEndian(
          Uint8List.fromList(hexData.getRange(1, 3).toList()));
      size = parse2ByteValueBigEndian(
          Uint8List.fromList(hexData.getRange(3, 5).toList()));
      checksum = (hexData[hexSize - 1]);

      if ((size + MIN_SIZE) == hexSize) {
        for (i = 0; i < size; i++) {
          rowData[i] = (hexData[DATA_OFFSET + i]);
        }
      } else {
        err = CYRET_ERR_DATA;
      }
    }
  } else {
    err = CYRET_ERR_CMD;
  }

  return (err, arrayId, rowNum, rowData, size, checksum);
}

(int, int, Uint8List, int, int) CyBtldr_ParseRowData_v1(
    int bufSize, String buffer) {
  const int MIN_SIZE = 4; //4-addr
  const int DATA_OFFSET = 4;

  int i;
  int hexSize;
  Uint8List hexData = Uint8List(MAX_BUFFER_SIZE);
  int err = CYRET_SUCCESS;
  int address = 0;
  Uint8List rowData = Uint8List(MAX_BUFFER_SIZE);
  int checksum = 0;
  int size = 0;

  if (bufSize <= MIN_SIZE) {
    err = CYRET_ERR_LENGTH;
  } else if (buffer[0].codeUnitAt(0) == ':'.codeUnitAt(0)) {
    (err, hexData, hexSize) = CyBtldr_FromAscii(
        bufSize - 1, Uint8List.fromList(buffer.substring(1, 2).codeUnits));

    if (CYRET_SUCCESS == err) {
      address = parse4ByteValueLittleEndian(hexData);
      checksum = 0;

      if (MIN_SIZE < hexSize) {
        size = hexSize - MIN_SIZE;
        for (i = 0; i < size; i++) {
          rowData[i] = (hexData[DATA_OFFSET + i]);
          checksum += rowData[i];
        }
      } else {
        err = CYRET_ERR_DATA;
      }
    }
  } else {
    err = CYRET_ERR_CMD;
  }

  return (err, address, rowData, size, checksum);
}

(int, int, int) CyBtldr_ParseAppStartAndSize_v1(
    int appStart, int appSize, int lineIndex) {
  const int APPINFO_META_HEADER_SIZE = 11;
  const String APPINFO_META_HEADER = "@APPINFO:0x";
  const int APPINFO_META_SEPERATOR_SIZE = 3;
  const String APPINFO_META_SEPERATOR = ",0x";
  const String APPINFO_META_SEPERATOR_START = ",";

  //long fp = ftell(dataFile);
  appStart = 0xffffffff;
  appSize = 0;
  int seperatorIndex;
  int err = CYRET_SUCCESS;
  int i;
  do {
    var (e, s, rowLength) = CyBtldr_ReadLine(lineIndex);
    err = e;
    if (err == CYRET_SUCCESS) {
      if (s[0] == ':') {
        var (_, addr, _, rowSize, _) = CyBtldr_ParseRowData_v1(rowLength, s);

        if (addr < appStart) {
          appStart = addr;
        }
        appSize += rowSize;
      } else if (rowLength >= APPINFO_META_HEADER_SIZE &&
          strncmp(s, APPINFO_META_HEADER, APPINFO_META_HEADER_SIZE) == 0) {
        // find seperator index
        seperatorIndex = s.indexOf(APPINFO_META_SEPERATOR_START);
        if (strncmp(s + seperatorIndex.toString(), APPINFO_META_SEPERATOR,
                APPINFO_META_SEPERATOR_SIZE) ==
            0) {
          appStart = 0;
          appSize = 0;
          for (i = APPINFO_META_HEADER_SIZE; i < seperatorIndex; i++) {
            appStart <<= 4;
            appStart += CyBtldr_FromHex(s[i].codeUnitAt(0));
          }
          for (i = seperatorIndex + APPINFO_META_SEPERATOR_SIZE;
              i < rowLength;
              i++) {
            appSize <<= 4;
            appSize += CyBtldr_FromHex(s[i].codeUnitAt(0));
          }
        } else {
          err = CYRET_ERR_FILE;
        }
        break;
      }
    }
  } while (err == CYRET_SUCCESS);
  if (err == CYRET_ERR_EOF) {
    err = CYRET_SUCCESS;
  }
  // reset to the file to where we were
  if (err == CYRET_SUCCESS) {
    //fseek(dataFile, fp, SEEK_SET);
  }
  return (err, appStart, appSize);
}

int CyBtldr_CloseDataFile() {
  return CYRET_SUCCESS;
}

int strncmp(String s1, String s2, int num) {
  bool con = true;
  int index = 0;
  while (con) {
    if (index < num) {
      if (s1.length > index && s2.length > index) {
        if (!identical(s1[index], s2)) {
          return 0;
        } else {
          index++;
        }
      } else {
        con = false;
      }
    } else {
      con = false;
    }
  }
  return 1;
}
