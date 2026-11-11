import 'dart:io';
import 'dart:convert';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:path/path.dart' as p;
import 'package:args/args.dart';

// Try to import the internal parser API
import 'package:analyzer/src/dart/parser/parser.dart';

class StringLiteralInfo {
  final String filePath;
  final int line;
  final int column;
  final String literal;
  final String parentType;
  final String parentProperty;
  final String context; // e.g., "Text", "label:", "title:", "tooltip:", etc.
  final bool isInterpolation;
  final List<String> interpolationExpressions;

  StringLiteralInfo({
    required this.filePath,
    required this.line,
    required this.column,
    required this.literal,
    required this.parentType,
    required this.parentProperty,
    required this.context,
    required this.isInterpolation,
    required this.interpolationExpressions,
  });

  Map<String, dynamic> toJson() => {
    'file': filePath,
    'line': line,
    'column': column,
    'literal': literal,
    'parentType': parentType,
    'parentProperty': parentProperty,
    'context': context,
    'isInterpolation': isInterpolation,
    'interpolationExpressions': interpolationExpressions,
  };
}

class StringLiteralVisitor extends RecursiveAstVisitor<void> {
  final List<StringLiteralInfo> results = [];
  final LineInfo lineInfo;
  final String filePath;
  final String sourceCode;

  StringLiteralVisitor({
    required this.lineInfo,
    required this.filePath,
    required this.sourceCode,
  });

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _processStringLiteral(node, isInterpolation: false, interpolationExpressions: []);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    final expressions = <String>[];
    for (final element in node.elements) {
      if (element is InterpolationExpression) {
        expressions.add(sourceCode.substring(
          element.expression.offset,
          element.expression.end,
        ).trim());
      }
    }
    _processStringLiteral(node, isInterpolation: true, interpolationExpressions: expressions);
    super.visitStringInterpolation(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final combinedLiteral = node.strings
        .map((s) => s is SimpleStringLiteral ? s.literal : '')
        .join('');
    _processStringLiteral(node, isInterpolation: false, interpolationExpressions: [], combinedLiteral: combinedLiteral);
    super.visitAdjacentStrings(node);
  }

  void _processStringLiteral(
    AstNode node, {
    required bool isInterpolation,
    required List<String> interpolationExpressions,
    String? combinedLiteral,
  }) {
    final location = lineInfo.getLocation(node.offset);
    final String literal = combinedLiteral ??
        (node is SimpleStringLiteral
            ? node.literal
            : node is StringInterpolation
                ? _extractLiteralFromInterpolation(node)
                : '') as String;

    // Skip empty strings
    if (literal.trim().isEmpty) return;

    // Get parent context
    final parent = node.parent;
    String parentType = parent?.runtimeType.toString() ?? 'Unknown';
    String parentProperty = _getParentProperty(parent, node);
    String context = _determineContext(parent, node, parentProperty);

    results.add(StringLiteralInfo(
      filePath: filePath,
      line: location.lineNumber,
      column: location.columnNumber,
      literal: literal,
      parentType: parentType,
      parentProperty: parentProperty,
      context: context,
      isInterpolation: isInterpolation,
      interpolationExpressions: interpolationExpressions,
    ));
  }

  String _extractLiteralFromInterpolation(StringInterpolation node) {
    final buffer = StringBuffer();
    for (final element in node.elements) {
      if (element is InterpolationString) {
        buffer.write(element.value);
      } else if (element is InterpolationExpression) {
        buffer.write('\${...}');
      }
    }
    return buffer.toString();
  }

  String _getParentProperty(AstNode? parent, AstNode child) {
    if (parent == null) return '';
    // Try to find which property of the parent contains this child
    // This is a simplified approach
    return '';
  }

  String _determineContext(AstNode? parent, AstNode child, String parentProperty) {
    if (parent == null) return 'unknown';

    // Check for common widget patterns
    if (parent is NamedExpression) {
      final name = parent.name.label.name;
      if (['label', 'title', 'tooltip', 'hintText', 'helperText', 'errorText',
           'semanticLabel', 'placeholder', 'counterText', 'prefixText', 'suffixText'].contains(name)) {
        return name;
      }
    }

    // Check for Text widget
    if (parent is ArgumentList) {
      final grandParent = parent.parent;
      if (grandParent is InstanceCreationExpression) {
        final typeName = _getTypeName(grandParent.constructorName.type);
        if (typeName.contains('Text')) {
          return 'Text';
        }
        // Check for other common widgets with text properties
        if (['AppBar', 'Tab', 'MenuItem', 'ListTile', 'Button', 'Chip',
             'AlertDialog', 'SnackBar', 'Tooltip', 'RichText', 'TextSpan',
             'TextField', 'InputDecoration', 'Button', 'IconButton',
             'FloatingActionButton', 'PopupMenuItem', 'DropdownMenuItem',
             'ExpansionTile', 'Card', 'SettingsTile', 'ListPageRow',
             'SheetTitleBar', 'SheetHeader', 'InfoRow', 'PillSegment',
             'FieldBadge', 'HostedLinksSettingsTile', 'UsageStatsSection'].any(
                  (t) => typeName.contains(t))) {
          return typeName;
        }
      }
    }

    // Check for named arguments in method calls
    if (parent is NamedExpression) {
      final grandParent = parent.parent;
      if (grandParent is ArgumentList) {
        final greatGrandParent = grandParent.parent;
        if (greatGrandParent is MethodInvocation) {
          final methodName = greatGrandParent.methodName.name;
          if (['showSnackBar', 'showDialog', 'showBriefNotice', 'showToast'].contains(methodName)) {
            return 'dialog/$methodName';
          }
        }
      }
    }

    return parentProperty.isNotEmpty ? parentProperty : parent.runtimeType.toString();
  }

  String _getTypeName(TypeAnnotation? type) {
    if (type == null) return '';
    if (type is NamedType) {
      // Get the name from the type - use name2 which is a Token, get its lexeme
      return type.name2.lexeme ?? '';
    }
    return type.toString();
  }
}

Future<void> scanFile(String filePath, List<StringLiteralInfo> allResults) async {
  final file = File(filePath);
  if (!await file.exists()) return;

  final sourceCode = await file.readAsString();
  final lineInfo = LineInfo.fromContent(sourceCode);

  // Parse the Dart file using the internal Parser class
  final parser = Parser();
  final parseResult = parser.parseString(content: sourceCode, path: filePath);

  if (parseResult.errors.isNotEmpty) {
    // Log errors but continue
    for (final error in parseResult.errors) {
      print('Parse error in $filePath: ${error.message}');
    }
  }

  final visitor = StringLiteralVisitor(
    lineInfo: lineInfo,
    filePath: filePath,
    sourceCode: sourceCode,
  );

  parseResult.unit.visitChildren(visitor);
  allResults.addAll(visitor.results);
}

Future<void> scanDirectory(String dirPath, List<StringLiteralInfo> allResults,
    {List<String> excludePatterns = const []}) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return;

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final relativePath = p.relative(entity.path, from: dirPath);
      bool shouldExclude = false;
      for (final pattern in excludePatterns) {
        if (relativePath.contains(pattern)) {
          shouldExclude = true;
          break;
        }
      }
      if (!shouldExclude) {
        await scanFile(entity.path, allResults);
      }
    }
  }
}

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Input directory to scan', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Output JSON file', defaultsTo: 'literals.json')
    ..addOption('exclude', help: 'Comma-separated patterns to exclude (e.g., test,generated)');

  final argResults = parser.parse(args);

  final inputDir = argResults['input'] as String;
  final outputFile = argResults['output'] as String;
  final excludePatterns = (argResults['exclude'] as String?)?.split(',') ?? [];

  print('Scanning Dart files in: $inputDir');
  print('Exclude patterns: $excludePatterns');

  final allResults = <StringLiteralInfo>[];
  await scanDirectory(inputDir, allResults, excludePatterns: excludePatterns);

  print('Found ${allResults.length} string literals');

  // Group by file for better organization
  final byFile = <String, List<Map<String, dynamic>>>{};
  for (final result in allResults) {
    final relPath = p.relative(result.filePath, from: inputDir);
    byFile.putIfAbsent(relPath, () => []).add(result.toJson());
  }

  final output = {
    'timestamp': DateTime.now().toIso8601String(),
    'totalLiterals': allResults.length,
    'byFile': byFile,
  };

  final outputJson = const JsonEncoder.withIndent('  ').convert(output);
  await File(outputFile).writeAsString(outputJson);
  print('Results written to: $outputFile');
}