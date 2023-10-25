/// ****************************************************************************
///    HOST ERROR CODES
///*****************************************************************************
///
/// Different return codes from the bootloader host.  Functions are not
/// limited to these values, but are encouraged to use them when returning
/// standard error values.
///
/// 0 is successful, all other values indicate a failure.
///***************************************************************************
/* Completed successfully */
int CYRET_SUCCESS = 0x00;
/* File is not accessible */
int CYRET_ERR_FILE = 0x01;
/* Reached the end of the file */
int CYRET_ERR_EOF = 0x02;
/* The amount of data available is outside the expected range */
int CYRET_ERR_LENGTH = 0x03;
/* The data is not of the proper form */
int CYRET_ERR_DATA = 0x04;
/* The command is not recognized */
int CYRET_ERR_CMD = 0x05;
/* The expected device does not match the detected device */
int CYRET_ERR_DEVICE = 0x06;
/* The bootloader version detected is not supported */
int CYRET_ERR_VERSION = 0x07;
/* The checksum does not match the expected value */
int CYRET_ERR_CHECKSUM = 0x08;
/* The flash array is not valid */
int CYRET_ERR_ARRAY = 0x09;
/* The flash row is not valid */
int CYRET_ERR_ROW = 0x0A;
/* The bootloader is not ready to process data */
int CYRET_ERR_BTLDR = 0x0B;
/* The application is currently marked as active */
int CYRET_ERR_ACTIVE = 0x0C;
/* An unknown error occurred */
int CYRET_ERR_UNK = 0x0F;
/* The operation was aborted */
int CYRET_ABORT = 0xFF;

/* The communications object reported an error */
int CYRET_ERR_COMM_MASK = 0x2000;
/* The bootloader reported an error */
int CYRET_ERR_BTLDR_MASK = 0x4000;

/// ****************************************************************************
///    BOOTLOADER STATUS CODES
///*****************************************************************************
///
/// Different return status codes from the bootloader.
///
/// 0 is successful, all other values indicate a failure.
///***************************************************************************
/* Completed successfully */
int CYBTLDR_STAT_SUCCESS = 0x00;
/* The provided key does not match the expected value */
int CYBTLDR_STAT_ERR_KEY = 0x01;
/* The verification of flash failed */
int CYBTLDR_STAT_ERR_VERIFY = 0x02;
/* The amount of data available is outside the expected range */
int CYBTLDR_STAT_ERR_LENGTH = 0x03;
/* The data is not of the proper form */
int CYBTLDR_STAT_ERR_DATA = 0x04;
/* The command is not recognized */
int CYBTLDR_STAT_ERR_CMD = 0x05;
/* The expected device does not match the detected device */
int CYBTLDR_STAT_ERR_DEVICE = 0x06;
/* The bootloader version detected is not supported */
int CYBTLDR_STAT_ERR_VERSION = 0x07;
/* The checksum does not match the expected value */
int CYBTLDR_STAT_ERR_CHECKSUM = 0x08;
/* The flash array is not valid */
int CYBTLDR_STAT_ERR_ARRAY = 0x09;
/* The flash row is not valid */
int CYBTLDR_STAT_ERR_ROW = 0x0A;
/* The flash row is protected and can not be programmed */
int CYBTLDR_STAT_ERR_PROTECT = 0x0B;
/* The application is not valid and cannot be set as active */
int CYBTLDR_STAT_ERR_APP = 0x0C;
/* The application is currently marked as active */
int CYBTLDR_STAT_ERR_ACTIVE = 0x0D;
/* An unknown error occurred */
int CYBTLDR_STAT_ERR_UNK = 0x0F;

/// ****************************************************************************
///    VERSION INFORMATION
///*****************************************************************************
///
/// Major � Used to indicate binary compatibility.  If a change is incompatible
///         in any way with the prior release, the major version number will be
///         updated.
/// Minor � Used to indicate feature set.  If a new feature or functionality is
///         added beyond what was available in a prior release, the this number
///         will be updated.
/// Patch � Used to indicate very minor fixes.  If the code was modified to fix
///         a defect or to improve the quality in any way that does not add new
///         functionality or change APIs this version number will be updated.
///
/// 1.0   - Original (PSoC Creator 1.0 Beta 5)
/// 1.1   - Add checksum option (PSoC Creator 1.0 Production)
/// 1.2   - Add support for Multi Application Bootloaders
///
///***************************************************************************
int VERSION_MAJOR = 0x01;
int VERSION_MINOR = 0x02;
int VERSION_PATCH = 0x00;
