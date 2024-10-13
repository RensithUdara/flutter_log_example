import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

typedef ButtonFunction = void Function();

class UserLogScreen extends StatefulWidget {
  const UserLogScreen({super.key});

  static Widget builder(BuildContext context) {
    return const UserLogScreen();
  }

  @override
  UserLogScreenState createState() => UserLogScreenState();
}

class UserLogScreenState extends State<UserLogScreen> {
  List<File> logFiles = [];
  List<File> filteredLogFiles = [];
  String selectedLogLevel = 'All'; // Default value for log filter
  bool isLoading = false; // To manage loading state

  // Store remaining times for each file
  Map<File, Duration> fileRemainingTimes = {};

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() {
      isLoading = true;
    });

    final directory = await getExternalStorageDirectory();
    if (directory != null) {
      final logDirectory = Directory(directory.path);
      final logs = logDirectory
          .listSync()
          .where((file) => file is File && file.path.endsWith('.txt'))
          .map((file) => file as File)
          .toList();

      logs.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      final now = DateTime.now();
      fileRemainingTimes = {
        for (var file in logs)
          file: const Duration(days: 2) - now.difference(file.lastModifiedSync())
      };

      if (!mounted) return; // Check if the widget is still in the tree
      setState(() {
        logFiles = logs;
        filteredLogFiles = logs;
        isLoading = false;
      });
    } else {
      if (!mounted) return; // Check if the widget is still in the tree
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String> _readLogFile(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  void _filterLogsByLevel(String logLevel) {
    if (logLevel == 'All') {
      setState(() {
        filteredLogFiles = logFiles;
      });
    } else {
      setState(() {
        filteredLogFiles = logFiles
            .where((file) => file.path.contains(logLevel.toLowerCase()))
            .toList();
      });
    }
  }

  Future<bool> _requestManageStoragePermission() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        await openAppSettings();
        return false;
      }
    }
    return status.isGranted;
  }

  Future<void> _downloadLogFile(File file) async {
    bool isGranted = await _requestManageStoragePermission();

    if (isGranted) {
      try {
        final downloadsDirectory = Directory('/storage/emulated/0/Download');

        if (downloadsDirectory.existsSync()) {
          final newFilePath =
              '${downloadsDirectory.path}/${file.path.split('/').last}';
          final newFile = File(newFilePath);

          if (newFile.existsSync()) {
            if (!mounted) return; // Check if the widget is still in the tree
            _showRetryDialog(
              context: context,
              title: 'File Already Exists',
              message: 'The file already exists. Overwrite?',
              primaryButtonLabel: 'Overwrite',
              primaryButtonFunction: () async {
                await _overwriteFile(newFilePath, file);
              },
              secondaryButtonLabel: 'Cancel',
              secondaryButtonFunction: () {},
            );
          } else {
            await file.copy(newFilePath);
            _showToast('Log file downloaded to: $newFilePath');
          }
        } else {
          _showToast('Unable to access Downloads directory');
        }
      } catch (e) {
        _showToast('Error downloading log file: $e');
      }
    } else {
      _showToast('Storage permission denied. Please enable it from settings.');
    }
  }

  Future<void> _overwriteFile(String filePath, File file) async {
    try {
      final newFile = await file.copy(filePath);
      _showToast('File overwritten at: ${newFile.path}');
    } catch (e) {
      _showToast('Error overwriting file: $e');
    }
  }

  Future<void> _deleteLogFile(File file) async {
    try {
      await file.delete();
      setState(() {
        logFiles.remove(file);
        filteredLogFiles.remove(file);
      });

      _showToast('Log file deleted successfully');
    } catch (e) {
      _showToast('Error deleting log file: $e');
    }
  }

  void _confirmDelete(File file) async {
    if (!mounted) return; // Check if the widget is still in the tree
    _showRetryDialog(
      context: context,
      title: 'Delete File',
      message: 'Are you sure you want to delete this file?',
      primaryButtonLabel: 'Delete',
      primaryButtonFunction: () async {
        await _deleteLogFile(file);
      },
      secondaryButtonLabel: 'Cancel',
      secondaryButtonFunction: () {},
    );
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    if (days > 0) {
      return '$days days, $hours hours';
    } else if (hours > 0) {
      return '$hours hours, $minutes minutes';
    } else {
      return '$minutes minutes';
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y, HH:mm').format(date);
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showRetryDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String primaryButtonLabel,
    required ButtonFunction primaryButtonFunction,
    required String secondaryButtonLabel,
    required ButtonFunction secondaryButtonFunction,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                secondaryButtonFunction();
                Navigator.of(context).pop();
              },
              child: Text(secondaryButtonLabel),
            ),
            ElevatedButton(
              onPressed: () {
                primaryButtonFunction();
                Navigator.of(context).pop();
              },
              child: Text(primaryButtonLabel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Log Files'),
        backgroundColor: const Color(0xFF1E88E5), // Changed color
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 8, // Reduce elevation
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Logs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_list,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 8),
                        const Text('Filter by Log Level: '),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedLogLevel,
                            isExpanded: true,
                            underline: Container(),
                            items: <String>[
                              'All',
                              'info',
                              'warning',
                              'error',
                              'debug'
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedLogLevel = newValue!;
                              });
                              _filterLogsByLevel(selectedLogLevel);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadLogFiles,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredLogFiles.isEmpty
                      ? const Center(
                          child: Text(
                          'No logs available',
                          style: TextStyle(fontSize: 16),
                        ))
                      : ListView.builder(
                          itemCount: filteredLogFiles.length,
                          itemBuilder: (context, index) {
                            final logFile = filteredLogFiles[index];
                            final remainingTime = fileRemainingTimes[logFile];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 8, // Changed to reduce the shadow
                              child: ListTile(
                                leading: const Icon(
                                  Icons.insert_drive_file,
                                  color: Colors.blueAccent, // Updated color
                                ),
                                title: Text(
                                  logFile.path.split('/').last,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Size: ${(logFile.lengthSync() / 1024).toStringAsFixed(2)} KB',
                                      style: TextStyle(
                                          color: Colors.grey[600], fontSize: 12),
                                    ),
                                    Text(
                                      'Last Modified: ${_formatDate(logFile.lastModifiedSync())}',
                                      style: TextStyle(
                                          color: Colors.grey[600], fontSize: 12),
                                    ),
                                    if (remainingTime != null)
                                      Text(
                                        'Remaining Time: ${_formatDuration(remainingTime)}',
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 12),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.download,
                                          color: Colors.green),
                                      onPressed: () =>
                                          _downloadLogFile(logFile),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _confirmDelete(logFile),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  final logContents =
                                      await _readLogFile(logFile);
                                  if (!mounted) return; // Check if the widget is still in the tree
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(logFile.path.split('/').last),
                                      content: SingleChildScrollView(
                                        child: Text(logContents),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _downloadLogFile(logFile);
                                          },
                                          child: const Text('Download'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
