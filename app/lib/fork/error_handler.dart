// Fork-specific error handling for DSH-Go
// Provides red error screen instead of gray, and logs errors to file

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Initialize fork-specific error handling
/// Call this early in main() before runApp()
void initializeForkErrorHandling() {
  // Set up Flutter framework error handler
  FlutterError.onError = _handleFlutterError;
  
  // Set up error widget builder for red error screens
  ErrorWidget.builder = _buildErrorWidget;
  
  // Handle async errors
  PlatformDispatcher.instance.onError = _handlePlatformError;
}

/// Handle Flutter framework errors
void _handleFlutterError(FlutterErrorDetails details) {
  final error = details.exception;
  final stack = details.stack ?? StackTrace.current;
  final library = details.library ?? 'unknown';
  final context = details.context?.toString() ?? 'unknown';
  
  final logEntry = _formatErrorLog(
    'FlutterError',
    error,
    stack,
    library: library,
    context: context,
    informationCollector: details.informationCollector,
  );
  
  _writeErrorLog(logEntry);
  
  // Also call default handler in debug mode
  if (kDebugMode) {
    FlutterError.dumpErrorToConsole(details);
  }
}

/// Handle platform-level async errors
bool _handlePlatformError(Object error, StackTrace stack) {
  final logEntry = _formatErrorLog(
    'PlatformError',
    error,
    stack,
  );
  
  _writeErrorLog(logEntry);
  
  // Return true to indicate we handled it
  return true;
}

/// Build a red error widget instead of the default gray one
Widget _buildErrorWidget(FlutterErrorDetails details) {
  final error = details.exception;
  final stack = details.stack;
  
  return Material(
    color: Colors.red.shade50,
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Application Error',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  error.toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (stack != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Stack Trace:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    stack.toString(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'This error has been logged. Please report it with the error log file.',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Format error log entry
String _formatErrorLog(
  String type,
  Object error,
  StackTrace stack, {
  String? library,
  String? context,
  InformationCollector? informationCollector,
}) {
  final buffer = StringBuffer();
  buffer.writeln('=== ERROR LOG ===');
  buffer.writeln('Time: ${DateTime.now().toIso8601String()}');
  buffer.writeln('Type: $type');
  buffer.writeln('Error: $error');
  buffer.writeln('Stack Trace:\n$stack');
  if (library != null) buffer.writeln('Library: $library');
  if (context != null) buffer.writeln('Context: $context');
  if (informationCollector != null) {
    buffer.writeln('Additional Info:');
    buffer.writeln(informationCollector());
  }
  buffer.writeln('=== END ERROR LOG ===\n');
  return buffer.toString();
}

/// Write error log to file
Future<void> _writeErrorLog(String logEntry) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/dsh_go_error_log.txt');
    
    // Append to log file (with rotation if too large)
    await logFile.writeAsString(logEntry, mode: FileMode.append);
    
    // Rotate if file exceeds 1MB
    final stat = await logFile.stat();
    if (stat.size > 1024 * 1024) {
      final lines = logFile.readAsLinesSync();
      if (lines.length > 1000) {
        await logFile.writeAsString(lines.skip(lines.length - 500).join('\n') + '\n');
      }
    }
  } catch (e) {
    // Ignore logging errors to avoid infinite loops
    if (kDebugMode) {
      debugPrint('Failed to write error log: $e');
    }
  }
}

/// Read error logs for debugging
Future<String> readErrorLogs({int maxLines = 200}) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/dsh_go_error_log.txt');
    
    if (!await logFile.exists()) {
      return 'No error logs found.';
    }
    
    final lines = await logFile.readAsLines();
    if (lines.length > maxLines) {
      return lines.skip(lines.length - maxLines).join('\n');
    }
    return lines.join('\n');
  } catch (e) {
    return 'Failed to read error logs: $e';
  }
}

/// Clear error logs
Future<void> clearErrorLogs() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/dsh_go_error_log.txt');
    if (await logFile.exists()) {
      await logFile.delete();
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Failed to clear error logs: $e');
    }
  }
}