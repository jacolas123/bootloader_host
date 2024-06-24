// ignore_for_file: non_constant_identifier_names, camel_case_types, constant_identifier_names

import 'dart:io';
import 'dart:typed_data';
import 'package:bootloader_host/ProgressProvider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path/path.dart' as path;
import '../cybtldr_command.dart';

import 'cybtldr_parse.dart';
import 'cybtldr_utils.dart';
import 'cybtldr_api.dart';

int g_abort = 0;

enum CyBtldr_Action {
  /* Perform a Program operation*/
  PROGRAM,
  /* Perform an Erase operation */
  ERASE,
  /* Perform a Verify operation */
  VERIFY,
}

Future<int> ProcessDataRow_v0(
    CyBtldr_Action action, int rowSize, Uint8List rowData) async {
  var (err, arrayId, rowNum, hexData, bufSize, checksum) =
      CyBtldr_ParseRowData(rowSize, rowData);
  if (CYRET_SUCCESS == err) {
    switch (action) {
      case CyBtldr_Action.ERASE:
        err = await CyBtldr_EraseRow(arrayId, rowNum);
        break;
      case CyBtldr_Action.PROGRAM:
        err = await CyBtldr_ProgramRow(arrayId, rowNum, hexData, bufSize);
        if (CYRET_SUCCESS != err) {
          break;
        }
      /* Continue on to verify the row that was programmed */
      case CyBtldr_Action.VERIFY:
        checksum = (checksum +
            arrayId +
            rowNum +
            (rowNum >> 8) +
            bufSize +
            (bufSize >> 8));
        err = await CyBtldr_VerifyRow(arrayId, rowNum, checksum);
        break;
    }
  }
  /*
  if (CYRET_SUCCESS == err && NULL != update)
      update(arrayId, rowNum);
  */
  return err;
}

Future<int> ProcessDataRow_v1(
    CyBtldr_Action action, int rowSize, String rowData) async {
  var (err, address, buffer, bufSize, _) =
      CyBtldr_ParseRowData_v1(rowSize, rowData);

  if (CYRET_SUCCESS == err) {
    switch (action) {
      case CyBtldr_Action.ERASE:
        err = await CyBtldr_EraseRow_v1(address);
        break;
      case CyBtldr_Action.PROGRAM:
        err = await CyBtldr_ProgramRow_v1(address, buffer, bufSize);
        break;
      case CyBtldr_Action.VERIFY:
        err = await CyBtldr_VerifyRow_v1(address, buffer, bufSize);
        break;
    }
  }
  /*
        if (CYRET_SUCCESS == err && NULL != update)
            update(0, (uint16_t)(address >> 16));
*/
  return err;
}

Future<int> ProcessMetaRow_v1(int rowSize, String rowData) async {
  const int EIV_META_HEADER_SIZE = 5;
  const String EIV_META_HEADER = "@EIV:";

  int err = CYRET_SUCCESS;
  if (rowSize >= EIV_META_HEADER_SIZE &&
      strncmp(rowData, EIV_META_HEADER, EIV_META_HEADER_SIZE) == 0) {
    var (_, buffer, bufSize) = CyBtldr_FromAscii(rowSize - EIV_META_HEADER_SIZE,
        Uint8List.fromList(rowData.substring(EIV_META_HEADER_SIZE).codeUnits));
    err = await CyBtldr_SetEncryptionInitialVector(bufSize, buffer);
  }
  return err;
}

Future<int> RunAction_v0(CyBtldr_Action action, int lineLen, String line,
    int appId, Uint8List securityKey, ProgressProvider provider) async {
  const int INVALID_APP = 0xFF;
  int siliconId = 0;
  int siliconRev = 0;
  int chksumtype = Cybtldr_ChecksumType.SUM_CHECKSUM.value;
  int isValid;
  int isActive;
  int err;
  int bootloaderEntered = 0;

  (err, siliconId, siliconRev, chksumtype) =
      CyBtldr_ParseHeader(lineLen, Uint8List.fromList(line.codeUnits));
  Cybtldr_ChecksumType t = Cybtldr_ChecksumType.CRC_CHECKSUM;
  if (chksumtype == Cybtldr_ChecksumType.SUM_CHECKSUM.value) {
    t = Cybtldr_ChecksumType.SUM_CHECKSUM;
  }
  if (CYRET_SUCCESS == err) {
    CyBtldr_SetCheckSumType(t);

    err = await CyBtldr_StartBootloadOperation(
        siliconId, siliconRev, securityKey);
    bootloaderEntered = 1;

    appId -=
        1; /* 1 and 2 are legal inputs to function. 0 and 1 are valid for bootloader component */
    if (appId > 1) {
      appId = INVALID_APP;
    }

    if ((CYRET_SUCCESS == err) && (appId != INVALID_APP)) {
      /* This will return error if bootloader is for single app */
      (err, isValid, isActive) = await CyBtldr_GetApplicationStatus(appId);

      /* Active app can be verified, but not programmed or erased */
      if (CYRET_SUCCESS == err &&
          CyBtldr_Action.VERIFY != action &&
          isActive == 1) {
        /* This is multi app */
        err = CYRET_ERR_ACTIVE;
      }
    }
  }
  int lineIndex = 1;
  while (CYRET_SUCCESS == err) {
    if (g_abort == 1) {
      err = CYRET_ABORT;
      break;
    }
    provider.setCurrentProgress(lineIndex);
    (err, line, lineLen) = CyBtldr_ReadLine(lineIndex);
    lineIndex++;
    if (CYRET_SUCCESS == err) {
      err = await ProcessDataRow_v0(
          action, lineLen, Uint8List.fromList(line.codeUnits));
    } else if (CYRET_ERR_EOF == err) {
      err = CYRET_SUCCESS;
      break;
    }
  }

  if (err == CYRET_SUCCESS) {
    if (CyBtldr_Action.PROGRAM == action && INVALID_APP != appId) {
      (err, isValid, isActive) = await CyBtldr_GetApplicationStatus(appId);

      if (CYRET_SUCCESS == err) {
        /* If valid set the active application to what was just programmed */
        /* This is multi app */
        err = (0 == isValid)
            ? await CyBtldr_SetApplicationStatus(appId)
            : CYRET_ERR_CHECKSUM;
      } else if (CYBTLDR_STAT_ERR_CMD == (err ^ CYRET_ERR_BTLDR_MASK)) {
        /* Single app - restore previous CYRET_SUCCESS */
        err = CYRET_SUCCESS;
      }
    } else if (CyBtldr_Action.PROGRAM == action ||
        CyBtldr_Action.VERIFY == action) {
      err = await CyBtldr_VerifyApplication();
    }
    await CyBtldr_EndBootloadOperation();
  } else if (CYRET_ERR_COMM_MASK != (CYRET_ERR_COMM_MASK & err) &&
      bootloaderEntered == 1) {
    await CyBtldr_EndBootloadOperation();
  }
  provider.hideProgress();
  return err;
}

Future<int> RunAction_v1(CyBtldr_Action action, int lineLen, String line,
    ProgressProvider provider) async {
  int blVer = 0;
  int siliconId = 0;
  int siliconRev = 0;
  int chksumtype = Cybtldr_ChecksumType.SUM_CHECKSUM.value;
  int appId = 0;
  int err;
  int bootloaderEntered = 0;
  int applicationStartAddr = 0xffffffff;
  int applicationSize = 0;
  int productId = 0;

  int lineIndex = 1;

  (err, siliconId, siliconRev, chksumtype, appId, productId) =
      CyBtldr_ParseHeader_v1(lineLen, Uint8List.fromList(line.codeUnits));

  if (CYRET_SUCCESS == err) {
    Cybtldr_ChecksumType t = Cybtldr_ChecksumType.CRC_CHECKSUM;
    if (chksumtype == Cybtldr_ChecksumType.SUM_CHECKSUM.value) {
      t = Cybtldr_ChecksumType.SUM_CHECKSUM;
    }
    CyBtldr_SetCheckSumType(t);

    err = await CyBtldr_StartBootloadOperation_v1(
        siliconId, siliconRev, blVer, productId);
    if (err == CYRET_SUCCESS) {
      (err, applicationStartAddr, applicationSize) =
          CyBtldr_ParseAppStartAndSize_v1(
              applicationStartAddr, applicationSize, lineIndex);
      lineIndex++;
    }
    if (err == CYRET_SUCCESS) {
      err = await CyBtldr_SetApplicationMetaData(
          appId, applicationStartAddr, applicationSize);
    }
    bootloaderEntered = 1;
  }

  while (CYRET_SUCCESS == err) {
    if (g_abort == 1) {
      err = CYRET_ABORT;
      break;
    }
    String s = "";
    provider.setCurrentProgress(lineIndex);
    (err, s, lineLen) = CyBtldr_ReadLine(lineIndex);
    if (CYRET_SUCCESS == err) {
      switch (s[0]) {
        case '@':
          err = await ProcessMetaRow_v1(lineLen, s);
          break;
        case ':':
          err = await ProcessDataRow_v1(action, lineLen, s);
          break;
      }
    } else if (CYRET_ERR_EOF == err) {
      err = CYRET_SUCCESS;
      break;
    }
  }

  if (err == CYRET_SUCCESS &&
      (CyBtldr_Action.PROGRAM == action || CyBtldr_Action.VERIFY == action)) {
    err = await CyBtldr_VerifyApplication_v1(appId);
    await CyBtldr_EndBootloadOperation();
  } else if (CYRET_ERR_COMM_MASK != (CYRET_ERR_COMM_MASK & err) &&
      bootloaderEntered == 1) {
    await CyBtldr_EndBootloadOperation();
  }
  provider.hideProgress();
  return err;
}

Future<int> CyBtldr_RunAction(
    CyBtldr_Action action,
    String securityKey,
    int appId,
    File file,
    BluetoothDevice device,
    ProgressProvider provider) async {
  g_abort = 0;
  int lineLen;
  String line;

  int err;
  int fileVersion = 0;
  g_comm.SetDevice(device);
  err = await CyBtldr_OpenDataFile(file);
  if (CYRET_SUCCESS == err) {
    provider.setTotalProgress(dataFileData.length);
    (err, line, lineLen) = CyBtldr_ReadLine(0);
    // The file version determine the format of the cyacd\cyacd2 file and the set of protocol commands used.
    if (CYRET_SUCCESS == err) {
      (err, fileVersion) = CyBtldr_ParseCyacdFileVersion(
          path.basename(file.path),
          lineLen,
          Uint8List.fromList(line.codeUnits));
    }
    if (CYRET_SUCCESS == err) {
      switch (fileVersion) {
        case 0:
          err = await RunAction_v0(action, lineLen, line, appId,
              Uint8List.fromList(securityKey.codeUnits), provider);
          break;
        case 1:
          err = await RunAction_v1(action, lineLen, line, provider);
          break;
        default:
          err = CYRET_ERR_FILE;
          break;
      }
      g_comm.CloseConnection();
    }

    CyBtldr_CloseDataFile();
  }

  return err;
}

Future<int> CyBtldr_Program(File file, String securityKey, int appId,
    BluetoothDevice device, ProgressProvider provider) async {
  return await CyBtldr_RunAction(
      CyBtldr_Action.PROGRAM, securityKey, appId, file, device, provider);
}

Future<int> CyBtldr_Erase(File file, String securityKey, BluetoothDevice device,
    ProgressProvider provider) async {
  return await CyBtldr_RunAction(
      CyBtldr_Action.ERASE, securityKey, 0, file, device, provider);
}

Future<int> CyBtldr_Verify(File file, String securityKey,
    BluetoothDevice device, ProgressProvider provider) async {
  return await CyBtldr_RunAction(
      CyBtldr_Action.VERIFY, securityKey, 0, file, device, provider);
}

int CyBtldr_Abort() {
  g_abort = 1;
  return CYRET_SUCCESS;
}
