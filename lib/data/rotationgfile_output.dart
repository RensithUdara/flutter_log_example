import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class RotatingFileOutput extends LogOutput {
  final String baseFileName;
  final int maxFileSize; // in bytes
  final int maxFiles; // Maximum number of backup files to keep
  final String userCode; // Unique code for the user

  late String _logDirectory;
  final Map<Level, File> _logFiles = {};

  String? _deviceType; // Dynamically fetched device type
  String? _versionNumber; // Dynamically fetched app version

  RotatingFileOutput({
    required this.baseFileName,
    required this.userCode, // Add userCode as required parameter
    this.maxFileSize = 1024 * 1024, // Default 1 MB
    this.maxFiles = 6,
    required String deviceType,
    required String versionNumber, // Default to keep 6 rotated files
  });

  @override
  Future<void> init() async {
    super.init();
    final directory = await getExternalStorageDirectory();
    _logDirectory = directory!.path;

    // Fetch device type and version dynamically
    await _fetchDeviceInfo();
    await _fetchAppVersion();
  }

  // Fetch device information dynamically
  Future<void> _fetchDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      _deviceType = 'Android ${androidInfo.model}';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      _deviceType = 'iOS ${iosInfo.model}';
    } else {
      _deviceType = 'Unknown Device';
    }
  }

  // Fetch app version dynamically
  Future<void> _fetchAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    _versionNumber = packageInfo.version;
  }

  // Get or create a log file for a specific level when logging occurs
  File _getLogFileForLevel(Level level) {
    if (!_logFiles.containsKey(level)) {
      final logFileName = '$_logDirectory/${_getFileNameForLevel(level)}.txt';
      final logFile = File(logFileName);

      if (!logFile.existsSync()) {
        logFile.createSync(recursive: true);
      }
      _logFiles[level] = logFile;
    }
    return _logFiles[level]!;
  }

  // Generate the log file name based on the log level
  String _getFileNameForLevel(Level level) {
    switch (level) {
      case Level.error:
        return '${baseFileName}_error';
      case Level.warning:
        return '${baseFileName}_warning';
      case Level.info:
        return '${baseFileName}_info';
      case Level.debug:
        return '${baseFileName}_debug';
      case Level.verbose:
        return '${baseFileName}_verbose';
      case Level.wtf:
        return '${baseFileName}_wtf';
      default:
        return '${baseFileName}_log'; // Default log file name if level is not matched
    }
  }

  @override
  void output(OutputEvent event) {
    final level = event.level;
    final logFile = _getLogFileForLevel(level);

    for (var line in event.lines) {
      // If device info and version haven't been fetched yet, wait until they're available
      if (_deviceType == null || _versionNumber == null) {
        // Defer writing the log entry until the device type and version are available
        return;
      }

      // Include userCode, deviceType, and versionNumber in the log entry
      final logEntry =
          'UserCode: $userCode | DeviceType: $_deviceType | Version: $_versionNumber | $line';

      _checkFileSizeAndRotate(logFile, level);
      logFile.writeAsStringSync('$logEntry\n', mode: FileMode.append);
    }
  }

  void _checkFileSizeAndRotate(File logFile, Level level) {
    if (logFile.lengthSync() > maxFileSize) {
      _rotateFiles(logFile, level);
    }
  }

  void _rotateFiles(File logFile, Level level) {
    final baseFileNameForLevel = _getFileNameForLevel(level);

    for (var i = maxFiles - 1; i > 0; i--) {
      final oldFile = File('$_logDirectory/$baseFileNameForLevel.$i.txt');
      final newFile = File('$_logDirectory/$baseFileNameForLevel.${i + 1}.txt');
      if (oldFile.existsSync()) {
        if (i == maxFiles - 1) {
          oldFile.deleteSync(); // Delete the oldest file
        } else {
          oldFile.renameSync(newFile.path); // Rename the file
        }
      }
    }

    // Rename the current log file
    final rotatedFile = File('$_logDirectory/$baseFileNameForLevel.txt');
    logFile.renameSync(rotatedFile.path);

    // Recreate the current log file
    logFile.createSync();
  }
}
