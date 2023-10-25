/* Maximum number of bytes to allocate for a single command.  */
import 'dart:typed_data';
import 'cybtldr_utils.dart';

const int MAX_COMMAND_SIZE = 512;

//STANDARD PACKET FORMAT:
// Multi byte entries are encoded in LittleEndian.
/// *****************************************************************************
/// [1-byte] [1-byte ] [2-byte] [n-byte] [ 2-byte ] [1-byte]
/// [ SOP  ] [Command] [ Size ] [ Data ] [Checksum] [ EOP  ]
///*****************************************************************************

/* The first byte of any boot loader command. */
const int CMD_START = 0x01;
/* The last byte of any boot loader command. */
const int CMD_STOP = 0x17;
/* The minimum number of bytes in a bootloader command. */
const int BASE_CMD_SIZE = 0x07;

/* Command identifier for verifying the checksum value of the bootloadable project. */
const int CMD_VERIFY_CHECKSUM = 0x31;
/* Command identifier for getting the number of flash rows in the target device. */
const int CMD_GET_FLASH_SIZE = 0x32;
/* Command identifier for getting info about the app status. This is only supported on multi app bootloader. */
const int CMD_GET_APP_STATUS = 0x33;
/* Command identifier for erasing a row of flash data from the target device. */
const int CMD_ERASE_ROW = 0x34;
/* Command identifier for making sure the bootloader host and bootloader are in sync. */
const int CMD_SYNC = 0x35;
/* Command identifier for setting the active application. This is only supported on multi app bootloader. */
const int CMD_SET_ACTIVE_APP = 0x36;
/* Command identifier for sending a block of data to the bootloader without doing anything with it yet. */
const int CMD_SEND_DATA = 0x37;
/* Command identifier for starting the boot loader.  All other commands ignored until this is sent. */
const int CMD_ENTER_BOOTLOADER = 0x38;
/* Command identifier for programming a single row of flash. */
const int CMD_PROGRAM_ROW = 0x39;
/* Command identifier for verifying the contents of a single row of flash. */
const int CMD_GET_ROW_CHECKSUM = 0x3A;
/* Command identifier for exiting the bootloader and restarting the target program. */
const int CMD_EXIT_BOOTLOADER = 0x3B;
/* Command to erase data */
const int CMD_ERASE_DATA = 0x44;
/* Command to program data. */
const int CMD_PROGRAM_DATA = 0x49;
/* Command to verify data */
const int CMD_VERIFY_DATA = 0x4A;
/* Command to set application metadata in bootloader SDK */
const int CMD_SET_METADATA = 0x4C;
/* Command to set encryption initial vector */
const int CMD_SET_EIV = 0x4D;

enum Cybtldr_ChecksumType {
  SUM_CHECKSUM(0x00),
  CRC_CHECKSUM(0x01);

  const Cybtldr_ChecksumType(this.value);
  final int value;
}

Cybtldr_ChecksumType CyBtldr_Checksum = Cybtldr_ChecksumType.SUM_CHECKSUM;

Uint8List fillData16(int data) {
  Uint8List buf = Uint8List(2);
  buf[0] = data;
  buf[1] = data >> 8;
  return buf;
}

Uint8List fillData32(int data) {
  Uint8List ret = Uint8List(4);
  Uint8List ret1 = fillData16(data);
  ret[0] = ret1[0];
  ret[1] = ret1[1];
  Uint8List sec = fillData16((data >> 16));
  ret[2] = sec[0];
  ret[3] = sec[1];
  return ret;
}

int CyBtldr_ComputeChecksum16bit(Uint8List buf, int size) {
  int bufIndex = 0;
  if (CyBtldr_Checksum == Cybtldr_ChecksumType.CRC_CHECKSUM) {
    int crc = 0xffff;

    int tmp;
    int i;

    if (size == 0) return (~crc);

    do {
      tmp = 0x00ff & buf[bufIndex++];
      for (i = 0; i < 8; i++, tmp >>= 1) {
        if (((crc & 0x0001) ^ (tmp & 0x0001)) > 0) {
          crc = (crc >> 1) ^ 0x8408;
        } else {
          crc >>= 1;
        }
      }
    } while ((--size) > 0);

    crc = ~crc;
    tmp = crc;
    crc = (crc << 8) | (tmp >> 8 & 0xFF);

    return crc;
  } else /* SUM_CHECKSUM */
  {
    int sum = 0;
    while (size-- > 0) {
      sum += buf[bufIndex++];
    }

    return (1 + ~sum);
  }
}

int CyBtldr_ComputeChecksum32bit(Uint8List buf, int size) {
  int g0 = 0x82F63B78;
  int g1 = (g0 >> 1) & 0x7fffffff;
  int g2 = (g0 >> 2) & 0x3fffffff;
  int g3 = (g0 >> 3) & 0x1fffffff;
  Uint32List table = Uint32List.fromList([
    0,
    g3,
    g2,
    (g2 ^ g3),
    g1,
    (g1 ^ g3),
    (g1 ^ g2),
    (g1 ^ g2 ^ g3),
    g0,
    (g0 ^ g3),
    (g0 ^ g2),
    (g0 ^ g2 ^ g3),
    (g0 ^ g1),
    (g0 ^ g1 ^ g3),
    (g0 ^ g1 ^ g2),
    (g0 ^ g1 ^ g2 ^ g3),
  ]);

  int bufIndex = 0;
  int crc = 0xFFFFFFFF;
  while (size != 0) {
    int i;
    --size;
    crc = crc ^ (buf[bufIndex]);
    bufIndex++;
    for (i = 1; i >= 0; i--) {
      crc = (crc >> 4) ^ table[crc & 0xF];
    }
  }
  return ~crc;
}

void CyBtldr_SetCheckSumType(Cybtldr_ChecksumType chksumType) {
  CyBtldr_Checksum = chksumType;
}

(int, int) ParseGenericCmdResult(
    Uint8List cmdBuf, int dataSize, int expectedSize) {
  int err = CYRET_SUCCESS;
  int cmdSize = dataSize + BASE_CMD_SIZE;
  int status = cmdBuf[1];
  if (cmdSize != expectedSize) {
    err = CYRET_ERR_LENGTH;
  } else if (status != CYRET_SUCCESS) {
    err = CYRET_ERR_BTLDR_MASK | (status);
  } else if (cmdBuf[0] != CMD_START ||
      cmdBuf[2] != (dataSize) ||
      cmdBuf[3] != ((dataSize >> 8)) ||
      cmdBuf[cmdSize - 1] != CMD_STOP) {
    err = CYRET_ERR_DATA;
  }
  return (err, status);
}

(int, int) CyBtldr_ParseDefaultCmdResult(Uint8List cmdBuf, int cmdSize) {
  return ParseGenericCmdResult(cmdBuf, 0, cmdSize);
}

// NOTE: If the cmd contains data bytes, make sure to call this after setting data bytes.
// Otherwise the checksum here will not include the data bytes.
(int, Uint8List) CreateCmd(Uint8List cmdBuf, int cmdSize, int cmdCode) {
  int checksum;
  cmdBuf[0] = CMD_START;
  cmdBuf[1] = cmdCode;
  Uint8List t1 = fillData16(cmdSize - BASE_CMD_SIZE);
  cmdBuf[2] = t1[0];
  cmdBuf[3] = t1[1];
  checksum = CyBtldr_ComputeChecksum16bit(cmdBuf, cmdSize - 3);
  Uint8List t2 = fillData16(checksum);
  cmdBuf[cmdSize - 3] = t2[0];
  cmdBuf[cmdSize - 2] = t2[1];
  cmdBuf[cmdSize - 1] = CMD_STOP;
  return (CYRET_SUCCESS, cmdBuf);
}

(int, int, Uint8List, int) CyBtldr_CreateEnterBootLoaderCmd(
    Uint8List securityKeyBuf) {
  const int RESULT_DATA_SIZE = 8;
  const int BOOTLOADER_SECURITY_KEY_SIZE = 6;
  int commandDataSize;
  int i;
  int resSize = BASE_CMD_SIZE + RESULT_DATA_SIZE;

  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);

  if (securityKeyBuf.isNotEmpty) {
    commandDataSize = BOOTLOADER_SECURITY_KEY_SIZE;
  } else {
    commandDataSize = 0;
  }
  int cmdSize = BASE_CMD_SIZE + commandDataSize;

  for (i = 0; i < commandDataSize; i++) {
    cmdBuf[i + 4] = securityKeyBuf[i];
  }
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_ENTER_BOOTLOADER);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, Uint8List, int) CyBtldr_CreateEnterBootLoaderCmd_v1(int productID) {
  const int COMMAND_DATA_SIZE = 6;
  const int RESULT_DATA_SIZE = 8;
  int resSize = BASE_CMD_SIZE + RESULT_DATA_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);

  Uint8List fill1 = fillData32(productID);
  cmdBuf[0] = fill1[0];
  cmdBuf[1] = fill1[1];
  cmdBuf[2] = fill1[2];
  cmdBuf[3] = fill1[3];

  cmdBuf[8] = 0;
  cmdBuf[9] = 0;
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_ENTER_BOOTLOADER);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, int, int, int) CyBtldr_ParseEnterBootLoaderCmdResult(
  Uint8List cmdBuf,
  int cmdSize,
) {
  const int RESULT_DATA_SIZE = 8;

  int siliconId = 0;
  int siliconRev = 0;
  int blVersion = 0;
  var (err, status) = ParseGenericCmdResult(cmdBuf, RESULT_DATA_SIZE, cmdSize);

  if (CYRET_SUCCESS == err) {
    siliconId =
        (cmdBuf[7] << 24) | (cmdBuf[6] << 16) | (cmdBuf[5] << 8) | cmdBuf[4];
    siliconRev = cmdBuf[8];
    blVersion = (cmdBuf[11] << 16) | (cmdBuf[10] << 8) | cmdBuf[9];
  }
  return (err, siliconId, siliconRev, blVersion, status);
}

(int, int, Uint8List, int) CyBtldr_CreateExitBootLoaderCmd() {
  int cmdSize = BASE_CMD_SIZE;
  int resSize = BASE_CMD_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_EXIT_BOOTLOADER);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, Uint8List, int) CyBtldr_CreateProgramRowCmd(
    int arrayId, int rowNum, Uint8List buf, int size, Uint8List cmdBuf) {
  const int COMMAND_DATA_SIZE = 3;
  int i;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE + size;

  cmdBuf[4] = arrayId;
  Uint8List fill1 = fillData16(rowNum);
  cmdBuf[5] = fill1[0];
  cmdBuf[6] = fill1[1];
  for (i = 0; i < size; i++) {
    cmdBuf[i + 7] = buf[i];
  }
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_PROGRAM_ROW);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int) CyBtldr_ParseProgramRowCmdResult(Uint8List cmdBuf, int cmdSize) {
  return CyBtldr_ParseDefaultCmdResult(cmdBuf, cmdSize);
}

(int, int, Uint8List, int) CyBtldr_CreateVerifyRowCmd(int arrayId, int rowNum) {
  const int RESULT_DATA_SIZE = 1;
  const int COMMAND_DATA_SIZE = 3;
  int resSize = BASE_CMD_SIZE + RESULT_DATA_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);
  cmdBuf[4] = arrayId;
  Uint8List fill1 = fillData16(rowNum);
  cmdBuf[5] = fill1[0];
  cmdBuf[6] = fill1[1];

  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_GET_ROW_CHECKSUM);

  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, int) CyBtldr_ParseVerifyRowCmdResult(Uint8List cmdBuf, int cmdSize) {
  const int RESULT_DATA_SIZE = 1;
  int checksum = 0;
  var (err, status) = ParseGenericCmdResult(cmdBuf, RESULT_DATA_SIZE, cmdSize);
  if (CYRET_SUCCESS == err) {
    checksum = cmdBuf[4];
  }
  return (err, checksum, status);
}

(int, int, Uint8List, int) CyBtldr_CreateEraseRowCmd(int arrayId, int rowNum) {
  const int COMMAND_DATA_SIZE = 3;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);
  cmdBuf[4] = arrayId;
  Uint8List fill = fillData16(rowNum);
  cmdBuf[5] = fill[0];
  cmdBuf[6] = fill[1];
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_ERASE_ROW);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int) CyBtldr_ParseEraseRowCmdResult(Uint8List cmdBuf, int cmdSize) {
  return CyBtldr_ParseDefaultCmdResult(cmdBuf, cmdSize);
}

(int, int, Uint8List, int) CyBtldr_CreateVerifyChecksumCmd() {
  const int RESULT_DATA_SIZE = 1;
  int cmdSize = BASE_CMD_SIZE;
  int resSize = BASE_CMD_SIZE + RESULT_DATA_SIZE;
  int err = 0;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);

  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_VERIFY_CHECKSUM);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, int) CyBtldr_ParseVerifyChecksumCmdResult(
    Uint8List cmdBuf, int cmdSize) {
  const int RESULT_DATA_SIZE = 1;
  var (err, status) = ParseGenericCmdResult(cmdBuf, RESULT_DATA_SIZE, cmdSize);
  int checksumValid = 0;
  if (CYRET_SUCCESS == err) {
    checksumValid = cmdBuf[4];
  }
  return (err, checksumValid, status);
}

(int, int, Uint8List, int) CyBtldr_CreateGetFlashSizeCmd(int arrayId) {
  const int RESULT_DATA_SIZE = 4;
  const int COMMAND_DATA_SIZE = 1;
  int resSize = BASE_CMD_SIZE + RESULT_DATA_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);
  cmdBuf[4] = arrayId;

  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_GET_FLASH_SIZE);

  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, int, int) CyBtldr_ParseGetFlashSizeCmdResult(
    Uint8List cmdBuf, int cmdSize) {
  const int RESULT_DATA_SIZE = 4;
  var (err, status) = ParseGenericCmdResult(cmdBuf, RESULT_DATA_SIZE, cmdSize);
  int startRow = 0;
  int endRow = 0;
  if (CYRET_SUCCESS == err) {
    startRow = (cmdBuf[5] << 8) | cmdBuf[4];
    endRow = (cmdBuf[7] << 8) | cmdBuf[6];
  }
  return (err, startRow, endRow, status);
}

(int, int, Uint8List, int) CyBtldr_CreateSendDataCmd(
    Uint8List buf, int size, Uint8List cmdBuf) {
  int i;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = size + BASE_CMD_SIZE;

  for (i = 0; i < size; i++) {
    cmdBuf[i + 4] = buf[i];
  }
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_SEND_DATA);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int) CyBtldr_ParseSendDataCmdResult(Uint8List cmdBuf, int cmdSize) {
  return CyBtldr_ParseDefaultCmdResult(cmdBuf, cmdSize);
}
/*
(int, int, int) CyBtldr_CreateSyncBootLoaderCmd(Uint8List cmdBuf) {
  int cmdSize = BASE_CMD_SIZE;
  int resSize = BASE_CMD_SIZE;

  return (CreateCmd(cmdBuf, cmdSize, CMD_SYNC), cmdSize, resSize);
}*/

(int, int, Uint8List, int) CyBtldr_CreateGetAppStatusCmd(int appId) {
  const int RESULT_DATA_SIZE = 2;
  const int COMMAND_DATA_SIZE = 1;
  int resSize = BASE_CMD_SIZE + RESULT_DATA_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);

  cmdBuf[4] = appId;
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_GET_APP_STATUS);

  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, int, int) CyBtldr_ParseGetAppStatusCmdResult(
    Uint8List cmdBuf, int cmdSize) {
  const int RESULT_DATA_SIZE = 2;
  var (err, status) = ParseGenericCmdResult(cmdBuf, RESULT_DATA_SIZE, cmdSize);
  int isValid = 0;
  int isActive = 0;
  if (CYRET_SUCCESS == err) {
    isValid = cmdBuf[4];
    isActive = cmdBuf[5];
  }
  return (err, isValid, isActive, status);
}

(int, int, Uint8List, int) CyBtldr_CreateSetActiveAppCmd(int appId) {
  const int COMMAND_DATA_SIZE = 1;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;

  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);

  cmdBuf[4] = appId;

  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_SET_ACTIVE_APP);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int) CyBtldr_ParseSetActiveAppCmdResult(Uint8List cmdBuf, int cmdSize) {
  return CyBtldr_ParseDefaultCmdResult(cmdBuf, cmdSize);
}

(int, int, Uint8List, int) CyBtldr_CreateProgramDataCmd(
    int address, int chksum, Uint8List buf, int size, Uint8List cmdBuf) {
  const int COMMAND_DATA_SIZE = 8;
  int i;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE + size;

  Uint8List fill1 = fillData32(address);
  cmdBuf[0] = fill1[0];
  cmdBuf[1] = fill1[1];
  cmdBuf[2] = fill1[2];
  cmdBuf[3] = fill1[3];
  Uint8List fill2 = fillData32(chksum);
  cmdBuf[4] = fill2[0];
  cmdBuf[5] = fill2[1];
  cmdBuf[6] = fill2[2];
  cmdBuf[7] = fill2[3];
  for (i = 0; i < size; i++) {
    cmdBuf[i + 4 + COMMAND_DATA_SIZE] = buf[i];
  }
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_PROGRAM_DATA);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, Uint8List, int) CyBtldr_CreateVerifyDataCmd(
    int address, int chksum, Uint8List buf, int size) {
  const int COMMAND_DATA_SIZE = 8;
  int i;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE + size;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);

  Uint8List fill1 = fillData32(address);
  cmdBuf[0] = fill1[0];
  cmdBuf[1] = fill1[1];
  cmdBuf[2] = fill1[2];
  cmdBuf[3] = fill1[3];

  Uint8List fill2 = fillData32(chksum);
  cmdBuf[4] = fill2[0];
  cmdBuf[5] = fill2[1];
  cmdBuf[6] = fill2[2];
  cmdBuf[7] = fill2[3];

  for (i = 0; i < size; i++) {
    cmdBuf[i + 4 + COMMAND_DATA_SIZE] = buf[i];
  }

  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_VERIFY_DATA);

  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, Uint8List, int) CyBtldr_CreateEraseDataCmd(int address) {
  const int COMMAND_DATA_SIZE = 4;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);

  Uint8List fill = fillData32(address);
  cmdBuf[0] = fill[0];
  cmdBuf[1] = fill[1];
  cmdBuf[2] = fill[2];
  cmdBuf[3] = fill[3];

  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_ERASE_DATA);

  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, Uint8List, int) CyBtldr_CreateVerifyChecksumCmd_v1(int appId) {
  const int COMMAND_DATA_SIZE = 1;
  int resSize = BASE_CMD_SIZE + 1;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);
  cmdBuf[4] = appId;
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_VERIFY_CHECKSUM);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, Uint8List, int) CyBtldr_CreateSetApplicationMetadataCmd(
    int appID, Uint8List buf) {
  int i;
  const int BTDLR_SDK_METADATA_SIZE = 8;
  const int COMMAND_DATA_SIZE = BTDLR_SDK_METADATA_SIZE + 1;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = BASE_CMD_SIZE + COMMAND_DATA_SIZE;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);
  cmdBuf[4] = appID;
  for (i = 0; i < BTDLR_SDK_METADATA_SIZE; i++) {
    cmdBuf[5 + i] = buf[i];
  }
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_SET_METADATA);
  return (err, cmdSize, cmdBuf, resSize);
}

(int, int, Uint8List, int) CyBtldr_CreateSetEncryptionInitialVectorCmd(
    Uint8List buf, int size) {
  int i;
  int resSize = BASE_CMD_SIZE;
  int cmdSize = BASE_CMD_SIZE + size;
  Uint8List cmdBuf = Uint8List(MAX_COMMAND_SIZE);
  for (i = 0; i < size; i++) {
    cmdBuf[4 + i] = buf[i];
  }
  int err = 0;
  (err, cmdBuf) = CreateCmd(cmdBuf, cmdSize, CMD_SET_EIV);
  return (err, cmdSize, cmdBuf, resSize);
}

//Try to parse a packet to determine its validity, if valid then return set the status param to the packet's status.
//Used to generate useful error messages. return 1 on success 0 otherwise.
(int, int) CyBtldr_TryParseParketStatus(Uint8List packet, int packetSize) {
  int dataSize;
  int readChecksum;
  int computedChecksum;
  if (packet.isEmpty || packetSize < BASE_CMD_SIZE || packet[0] != CMD_START) {
    return (CYBTLDR_STAT_ERR_UNK, 0);
  }
  int status = packet[1];
  dataSize = packet[2] | (packet[3] << 8);

  readChecksum = packet[dataSize + 4] | (packet[dataSize + 5] << 8);
  computedChecksum =
      CyBtldr_ComputeChecksum16bit(packet, BASE_CMD_SIZE + dataSize - 3);

  if (packet[dataSize + BASE_CMD_SIZE - 1] != CMD_STOP ||
      readChecksum != computedChecksum) {
    return (CYBTLDR_STAT_ERR_UNK, status);
  }
  return (CYRET_SUCCESS, status);
}
