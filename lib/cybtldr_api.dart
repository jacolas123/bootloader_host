import 'cybtldr_parse.dart';
import 'cybtldr_utils.dart';
import 'cybtldr_command.dart';
import 'cybtldr_uart_comms.dart';
import 'dart:typed_data';

/* The highest number of memory arrays for any device. This includes flash and EEPROM arrays */
const int MAX_DEV_ARRAYS = 0x80;
/* The default value if a flash array has not yet received data */
const int NO_FLASH_ARRAY_DATA = 0;
/* The maximum number of flash arrays */
const int MAX_FLASH_ARRAYS = 0x40;
/* The minimum array id for EEPROM arrays. */
const int MIN_EEPROM_ARRAY = 0x40;

Uint32List g_validRows = Uint32List(MAX_FLASH_ARRAYS);

CyBtldr_CommunicationsData g_comm = CyBtldr_CommunicationsData();

int min_int(int a, int b) {
  return (a < b) ? a : b;
}

Future<(int, Uint8List)> CyBtldr_TransferData(
    Uint8List inBuf, int inSize, int outSize) async {
  int err = g_comm.WriteData(inBuf, inSize);
  Uint8List outbuf = Uint8List(MAX_BUFFER_SIZE);
  if (CYRET_SUCCESS == err) {
    while (!g_comm.hasData()) {
      await Future.delayed(Duration(seconds: 1));
    }
    (err, outbuf) = g_comm.ReadData(outSize);
  }

  if (CYRET_SUCCESS != err) err |= CYRET_ERR_COMM_MASK;

  return (err, outbuf);
}

Future<int> CyBtldr_ValidateRow(int arrayId, int rowNum) async {
  int inSize;
  int outSize;
  int minRow = 0;
  int maxRow = 0;
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int status = CYRET_SUCCESS;
  int err = CYRET_SUCCESS;

  if (arrayId < MAX_FLASH_ARRAYS) {
    if (NO_FLASH_ARRAY_DATA == g_validRows[arrayId]) {
      (err, inSize, inBuf, outSize) = CyBtldr_CreateGetFlashSizeCmd(arrayId);
      if (CYRET_SUCCESS == err) {
        (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
      }
      if (CYRET_SUCCESS == err) {
        (err, minRow, maxRow, status) =
            CyBtldr_ParseGetFlashSizeCmdResult(outBuf, outSize);
      }
      if (CYRET_SUCCESS != status) {
        err = status | CYRET_ERR_BTLDR_MASK;
      }
      if (CYRET_SUCCESS == err) {
        if (CYRET_SUCCESS == status) {
          g_validRows[arrayId] = (minRow << 16) + maxRow;
        } else {
          err = status | CYRET_ERR_BTLDR_MASK;
        }
      }
    }
    if (CYRET_SUCCESS == err) {
      minRow = (g_validRows[arrayId] >> 16);
      maxRow = g_validRows[arrayId];
      if (rowNum < minRow || rowNum > maxRow) {
        err = CYRET_ERR_ROW;
      }
    }
  } else {
    err = CYRET_ERR_ARRAY;
  }

  return err;
}

Future<int> CyBtldr_StartBootloadOperation(
    int expSiId, int expSiRev, Uint8List securityKeyBuf) async {
  const int SUPPORTED_BOOTLOADER = 0x010000;
  const int BOOTLOADER_VERSION_MASK = 0xFF0000;
  int i;
  int inSize = 0;
  int outSize = 0;
  int siliconId = 0;
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int siliconRev = 0;
  int status = CYRET_SUCCESS;
  int err;

  int blVer = 0;
  for (i = 0; i < MAX_FLASH_ARRAYS; i++) {
    g_validRows[i] = NO_FLASH_ARRAY_DATA;
  }

  err = g_comm.OpenConnection();
  if (CYRET_SUCCESS != err) {
    err |= CYRET_ERR_COMM_MASK;
  }

  if (CYRET_SUCCESS == err) {
    (err, inSize, inBuf, outSize) =
        CyBtldr_CreateEnterBootLoaderCmd(securityKeyBuf);
  }
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, siliconId, siliconRev, blVer, status) =
        CyBtldr_ParseEnterBootLoaderCmdResult(outBuf, outSize);
  } else {
    (err, status) = CyBtldr_TryParseParketStatus(outBuf, outSize);
    if (err == CYRET_SUCCESS) {
      err = status |
          CYRET_ERR_BTLDR_MASK; //if the response we get back is a valid packet override the err with the response's status
    }
  }

  if (CYRET_SUCCESS == err) {
    if (CYRET_SUCCESS != status) {
      err = status | CYRET_ERR_BTLDR_MASK;
    }
    if (expSiId != siliconId || expSiRev != siliconRev) {
      err = CYRET_ERR_DEVICE;
    } else if ((blVer & BOOTLOADER_VERSION_MASK) != SUPPORTED_BOOTLOADER) {
      err = CYRET_ERR_VERSION;
    }
  }

  return err;
}

Future<int> CyBtldr_StartBootloadOperation_v1(
    int expSiId, int expSiRev, int blVer, int productID) async {
  int i;
  int inSize = 0;
  int outSize = 0;
  int siliconId = 0;
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int siliconRev = 0;
  int status = CYRET_SUCCESS;
  int err;

  for (i = 0; i < MAX_FLASH_ARRAYS; i++) {
    g_validRows[i] = NO_FLASH_ARRAY_DATA;
  }

  err = g_comm.OpenConnection();
  if (CYRET_SUCCESS != err) {
    err |= CYRET_ERR_COMM_MASK;
  }
  if (CYRET_SUCCESS == err) {
    (err, inSize, inBuf, outSize) =
        CyBtldr_CreateEnterBootLoaderCmd_v1(productID);
  }
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, siliconId, siliconRev, blVer, productID) =
        CyBtldr_ParseEnterBootLoaderCmdResult(outBuf, outSize);
  } else {
    (err, status) = CyBtldr_TryParseParketStatus(outBuf, outSize);
    if (err == CYRET_SUCCESS) {
      err = status |
          CYRET_ERR_BTLDR_MASK; //if the response we get back is a valid packet override the err with the response's status
    }
  }

  if (CYRET_SUCCESS == err) {
    if (CYRET_SUCCESS != status) {
      err = status | CYRET_ERR_BTLDR_MASK;
    }
    if (expSiId != siliconId || expSiRev != siliconRev) {
      err = CYRET_ERR_DEVICE;
    }
  }

  return err;
}

Future<(int, int, int)> CyBtldr_GetApplicationStatus(int appID) async {
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int status = CYRET_SUCCESS;
  var isValid = 0;
  var isActive = 0;

  var (err, inSize, inBuf, outSize) = CyBtldr_CreateGetAppStatusCmd(appID);
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, isValid, isActive, status) =
        CyBtldr_ParseGetAppStatusCmdResult(outBuf, outSize);
  } else {
    (err, status) = CyBtldr_TryParseParketStatus(outBuf, outSize);
    if (err == CYRET_SUCCESS) {
      err = status |
          CYRET_ERR_BTLDR_MASK; //if the response we get back is a valid packet override the err with the response's status
    }
  }

  if (CYRET_SUCCESS == err) {
    if (CYRET_SUCCESS != status) {
      err = status | CYRET_ERR_BTLDR_MASK;
    }
  }

  return (err, isValid, isActive);
}

Future<int> CyBtldr_SetApplicationStatus(int appID) async {
  int inSize = 0;
  int outSize = 0;
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int status = CYRET_SUCCESS;
  int err;

  (err, inSize, inBuf, outSize) = CyBtldr_CreateSetActiveAppCmd(appID);
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, status) = CyBtldr_ParseSetActiveAppCmdResult(outBuf, outSize);
  }

  if (CYRET_SUCCESS == err) {
    if (CYRET_SUCCESS != status) {
      err = status | CYRET_ERR_BTLDR_MASK;
    }
  }

  return err;
}

int CyBtldr_EndBootloadOperation() {
  int inSize;
  int err = CYRET_SUCCESS;
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  (err, inSize, inBuf, _) = CyBtldr_CreateExitBootLoaderCmd();
  if (CYRET_SUCCESS == err) {
    err = g_comm.WriteData(inBuf, inSize);

    if (CYRET_SUCCESS == err) {
      err = g_comm.CloseConnection();
    }

    if (CYRET_SUCCESS != err) {
      err |= CYRET_ERR_COMM_MASK;
    }
  }

  return err;
}

Future<(int, int, Uint8List)> SendData(
    Uint8List buf, int size, int maxRemainingDataSize, Uint8List outBuf) async {
  int offset = 0;
  int status = CYRET_SUCCESS;
  int inSize = 0, outSize = 0;
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  // size is the total bytes of data to transfer.
  // offset is the amount of data already transfered.
  // a is maximum amount of data allowed to be left over when this function ends.
  // (we can leave some data for caller (programRow, VerifyRow,...) to send.
  // TRANSFER_HEADER_SIZE is the amount of bytes this command header takes up.
  const int TRANSFER_HEADER_SIZE = 7;
  int subBufSize =
      min_int((g_comm.MaxTransferSize - TRANSFER_HEADER_SIZE), size);
  int err = CYRET_SUCCESS;
  //Break row into pieces to ensure we don't send too much for the transfer protocol
  while ((CYRET_SUCCESS == err) && ((size - offset) > maxRemainingDataSize)) {
    (err, inSize, inBuf, outSize) = CyBtldr_CreateSendDataCmd(
        Uint8List.fromList(buf.getRange(offset, buf.length).toList()),
        subBufSize,
        inBuf);
    if (CYRET_SUCCESS == err) {
      (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
    }
    if (CYRET_SUCCESS == err) {
      (err, status) = CyBtldr_ParseSendDataCmdResult(outBuf, outSize);
    }
    if (CYRET_SUCCESS != status) {
      err = status | CYRET_ERR_BTLDR_MASK;
    }
    offset += subBufSize;
  }
  return (err, offset, inBuf);
}

Future<int> CyBtldr_ProgramRow(
    int arrayID, int rowNum, Uint8List buf, int size) async {
  const int TRANSFER_HEADER_SIZE = 10;

  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int inSize;
  int outSize;
  int offset = 0;
  int subBufSize;
  int status = CYRET_SUCCESS;
  int err = CYRET_SUCCESS;

  if (arrayID < MAX_FLASH_ARRAYS) {
    err = await CyBtldr_ValidateRow(arrayID, rowNum);
  }

  if (CYRET_SUCCESS == err) {
    (err, offset, inBuf) = await SendData(
        buf, size, (g_comm.MaxTransferSize - TRANSFER_HEADER_SIZE), outBuf);
  }

  if (CYRET_SUCCESS == err) {
    subBufSize = size - offset;

    (err, inSize, buf, outSize) = CyBtldr_CreateProgramRowCmd(
        arrayID,
        rowNum,
        Uint8List.fromList(buf.getRange(offset, buf.length).toList()),
        subBufSize,
        inBuf);
    if (CYRET_SUCCESS == err) {
      (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
    }
    if (CYRET_SUCCESS == err) {
      (err, status) = CyBtldr_ParseProgramRowCmdResult(outBuf, outSize);
    }
    if (CYRET_SUCCESS != status) {
      err = status | CYRET_ERR_BTLDR_MASK;
    }
  }

  return err;
}

Future<int> CyBtldr_EraseRow(int arrayID, int rowNum) async {
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int inSize = 0;
  int outSize = 0;
  int status = CYRET_SUCCESS;
  int err = CYRET_SUCCESS;

  if (arrayID < MAX_FLASH_ARRAYS) {
    err = await CyBtldr_ValidateRow(arrayID, rowNum);
  }
  if (CYRET_SUCCESS == err) {
    (err, inSize, inBuf, outSize) = CyBtldr_CreateEraseRowCmd(arrayID, rowNum);
  }
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, status) = CyBtldr_ParseEraseRowCmdResult(outBuf, outSize);
  }
  if (CYRET_SUCCESS != status) {
    err = status | CYRET_ERR_BTLDR_MASK;
  }

  return err;
}

Future<int> CyBtldr_VerifyRow(int arrayID, int rowNum, int checksum) async {
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int inSize = 0;
  int outSize = 0;
  int rowChecksum = 0;
  int status = CYRET_SUCCESS;
  int err = CYRET_SUCCESS;

  if (arrayID < MAX_FLASH_ARRAYS) {
    err = await CyBtldr_ValidateRow(arrayID, rowNum);
  }
  if (CYRET_SUCCESS == err) {
    (err, inSize, inBuf, outSize) = CyBtldr_CreateVerifyRowCmd(arrayID, rowNum);
  }
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, rowChecksum, status) =
        CyBtldr_ParseVerifyRowCmdResult(outBuf, outSize);
  }
  if (CYRET_SUCCESS != status) {
    err = status | CYRET_ERR_BTLDR_MASK;
  }
  if ((CYRET_SUCCESS == err) && (rowChecksum != checksum)) {
    err = CYRET_ERR_CHECKSUM;
  }

  return err;
}

Future<int> CyBtldr_VerifyApplication() async {
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int inSize = 0;
  int outSize = 0;
  int checksumValid = 0;
  int status = CYRET_SUCCESS;

  int err = CYRET_SUCCESS;
  (err, inSize, inBuf, outSize) = CyBtldr_CreateVerifyChecksumCmd();
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, checksumValid, status) =
        CyBtldr_ParseVerifyChecksumCmdResult(outBuf, outSize);
  }
  if (CYRET_SUCCESS != status) {
    err = status | CYRET_ERR_BTLDR_MASK;
  }
  if ((CYRET_SUCCESS == err) && (checksumValid != 1)) {
    err = CYRET_ERR_CHECKSUM;
  }

  return err;
}

Future<int> CyBtldr_ProgramRow_v1(int address, Uint8List buf, int size) async {
  const int TRANSFER_HEADER_SIZE = 15;

  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int inSize;
  int outSize;
  int offset = 0;
  int subBufSize;
  int status = CYRET_SUCCESS;
  int err = CYRET_SUCCESS;

  int chksum = CyBtldr_ComputeChecksum32bit(buf, size);

  if (CYRET_SUCCESS == err) {
    (err, offset, inBuf) = await SendData(
        buf, size, (g_comm.MaxTransferSize - TRANSFER_HEADER_SIZE), outBuf);
  }

  if (CYRET_SUCCESS == err) {
    subBufSize = size - offset;

    (err, inSize, inBuf, outSize) = CyBtldr_CreateProgramDataCmd(
        address,
        chksum,
        Uint8List.fromList(buf.getRange(offset, buf.length).toList()),
        subBufSize,
        inBuf);
    if (CYRET_SUCCESS == err) {
      (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
    }
    if (CYRET_SUCCESS == err) {
      (err, status) = CyBtldr_ParseDefaultCmdResult(outBuf, outSize);
    }
    if (CYRET_SUCCESS != status) {
      err = status | CYRET_ERR_BTLDR_MASK;
    }
  }

  return err;
}

Future<int> CyBtldr_EraseRow_v1(int address) async {
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int inSize = 0;
  int outSize = 0;
  int status = CYRET_SUCCESS;
  int err = CYRET_SUCCESS;

  if (CYRET_SUCCESS == err) {
    (err, inSize, inBuf, outSize) = CyBtldr_CreateEraseDataCmd(address);
  }
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, status) = CyBtldr_ParseEraseRowCmdResult(outBuf, outSize);
  }
  if (CYRET_SUCCESS != status) {
    err = status | CYRET_ERR_BTLDR_MASK;
  }

  return err;
}

Future<int> CyBtldr_VerifyRow_v1(int address, Uint8List buf, int size) async {
  const int TRANSFER_HEADER_SIZE = 15;

  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int inSize;
  int outSize;
  int offset = 0;
  int subBufSize;
  int status = CYRET_SUCCESS;
  int err = CYRET_SUCCESS;

  int chksum = CyBtldr_ComputeChecksum32bit(buf, size);

  if (CYRET_SUCCESS == err) {
    (err, offset, inBuf) = await SendData(
        buf, size, (g_comm.MaxTransferSize - TRANSFER_HEADER_SIZE), outBuf);
  }

  if (CYRET_SUCCESS == err) {
    subBufSize = size - offset;

    (err, inSize, inBuf, outSize) = CyBtldr_CreateVerifyDataCmd(
        address,
        chksum,
        Uint8List.fromList(buf.getRange(offset, buf.length).toList()),
        subBufSize);
    if (CYRET_SUCCESS == err) {
      (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
    }
    if (CYRET_SUCCESS == err) {
      (err, status) = CyBtldr_ParseDefaultCmdResult(outBuf, outSize);
    }
    if (CYRET_SUCCESS != status) {
      err = status | CYRET_ERR_BTLDR_MASK;
    }
  }

  return err;
}

Future<int> CyBtldr_VerifyApplication_v1(int appId) async {
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int inSize = 0;
  int outSize = 0;
  int checksumValid = 0;
  int status = CYRET_SUCCESS;

  int err = CYRET_SUCCESS;
  (err, inSize, inBuf, outSize) = CyBtldr_CreateVerifyChecksumCmd_v1(appId);
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, checksumValid, status) =
        CyBtldr_ParseVerifyChecksumCmdResult(outBuf, outSize);
  }
  if (CYRET_SUCCESS != status) {
    err = status | CYRET_ERR_BTLDR_MASK;
  }
  if ((CYRET_SUCCESS == err) && (checksumValid != 1)) {
    err = CYRET_ERR_CHECKSUM;
  }

  return err;
}

Future<int> CyBtldr_SetApplicationMetaData(
    int appId, int appStartAddr, int appSize) async {
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);
  int status = CYRET_SUCCESS;

  Uint8List metadata = Uint8List(8);
  metadata[0] = appStartAddr;
  metadata[1] = (appStartAddr >> 8);
  metadata[2] = (appStartAddr >> 16);
  metadata[3] = (appStartAddr >> 24);
  metadata[4] = appSize;
  metadata[5] = (appSize >> 8);
  metadata[6] = (appSize >> 16);
  metadata[7] = (appSize >> 24);
  var (err, inSize, inBuf, outSize) =
      CyBtldr_CreateSetApplicationMetadataCmd(appId, metadata);
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, status) = CyBtldr_ParseDefaultCmdResult(outBuf, outSize);
  }
  if (CYRET_SUCCESS != status) {
    err = status | CYRET_ERR_BTLDR_MASK;
  }

  return err;
}

Future<int> CyBtldr_SetEncryptionInitialVector(int size, Uint8List buf) async {
  Uint8List inBuf = Uint8List(MAX_COMMAND_SIZE);
  Uint8List outBuf = Uint8List(MAX_COMMAND_SIZE);

  int inSize = 0;
  int outSize = 0;
  int status = CYRET_SUCCESS;

  int err = CYRET_SUCCESS;
  (err, inSize, inBuf, outSize) =
      CyBtldr_CreateSetEncryptionInitialVectorCmd(buf, size);
  if (CYRET_SUCCESS == err) {
    (err, outBuf) = await CyBtldr_TransferData(inBuf, inSize, outSize);
  }
  if (CYRET_SUCCESS == err) {
    (err, status) = CyBtldr_ParseDefaultCmdResult(outBuf, outSize);
  }
  if (CYRET_SUCCESS != status) {
    err = status | CYRET_ERR_BTLDR_MASK;
  }

  return err;
}
