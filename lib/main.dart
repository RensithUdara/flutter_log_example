import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:testapp/data/rotationgfile_output.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Initialize the logger with custom RotatingFileOutput
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log
      printTime: true, // Should each log print time
    ),
    output: RotatingFileOutput(
      baseFileName: "app_log",
      maxFileSize: 1024 * 1024, // Rotate when the log file exceeds 1 MB
      maxFiles: 6, // Keep up to 5 rotated log files
      userCode: '', // User-specific code
      deviceType: '', // Device type (e.g., Android, iOS)
      versionNumber: '', // Application version number
    ),
  );

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logger Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: MyHomePage(logger: logger),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final Logger logger;

  const MyHomePage({super.key, required this.logger});

  void _logVerbose() {
    logger.v('This is a verbose log message');
  }

  void _logDebug() {
    logger.d('This is a debug log message');
  }

  void _logInfo() {
    logger.i('This is an info log message');
  }

  void _logWarning() {
    logger.w('This is a warning log message');
  }

  void _logError() {
    logger.e('This is an error log message');
  }

  void _logWtf() {
    logger.wtf('This is a WTF log message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logger Example'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildLogButton(
              context,
              text: 'Log Verbose',
              icon: Icons.volume_up,
              color: Colors.blue,
              onPressed: _logVerbose,
            ),
            _buildLogButton(
              context,
              text: 'Log Debug',
              icon: Icons.bug_report,
              color: Colors.green,
              onPressed: _logDebug,
            ),
            _buildLogButton(
              context,
              text: 'Log Info',
              icon: Icons.info,
              color: Colors.lightBlue,
              onPressed: _logInfo,
            ),
            _buildLogButton(
              context,
              text: 'Log Warning',
              icon: Icons.warning,
              color: Colors.orange,
              onPressed: _logWarning,
            ),
            _buildLogButton(
              context,
              text: 'Log Error',
              icon: Icons.error,
              color: Colors.red,
              onPressed: _logError,
            ),
            _buildLogButton(
              context,
              text: 'Log WTF',
              icon: Icons.sentiment_very_dissatisfied,
              color: Colors.purple,
              onPressed: _logWtf,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogButton(BuildContext context,
      {required String text,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        trailing: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Log'),
        ),
      ),
    );
  }
}
