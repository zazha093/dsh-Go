// Draft Validator — field-level validation with rule-based fallback

import '../skills/skill_model.dart';

/// Result of field validation
class FieldValidationResult {
  const FieldValidationResult({
    required this.isValid,
    this.error,
    this.fallbackValue,
  });

  final bool isValid;
  final String? error;
  final dynamic fallbackValue;

  factory FieldValidationResult.valid() => const FieldValidationResult(isValid: true);
  factory FieldValidationResult.invalid(String error, {dynamic fallbackValue}) =>
      FieldValidationResult(isValid: false, error: error, fallbackValue: fallbackValue);
}

/// Validates AI-proposed skill draft field-by-field
class DraftValidator {
  DraftValidator({
    required this.locale,
  });

  final String locale;

  /// Validate entire skill draft, returning validated skill with fallbacks
  Skill validate(Skill aiSkill, Skill ruleBasedSkill) {
    // Validate each field, use rule-based fallback for invalid fields
    final name = _validateName(aiSkill.name, ruleBasedSkill.name);
    final kind = _validateKind(aiSkill.kind, ruleBasedSkill.kind);
    final goal = _validateGoal(aiSkill.goal, ruleBasedSkill.goal);
    final description = _validateDescription(aiSkill.description, ruleBasedSkill.description);
    final steps = _validateSteps(aiSkill.steps, ruleBasedSkill.steps, kind);
    final constraints = _validateConstraints(aiSkill.constraints, ruleBasedSkill.constraints);
    final requiredTools = _validateRequiredTools(aiSkill.requiredTools, ruleBasedSkill.requiredTools);
    final userInputs = _validateUserInputs(aiSkill.userInputs, ruleBasedSkill.userInputs);
    final executableSteps = _validateExecutableSteps(aiSkill.executableSteps, ruleBasedSkill.executableSteps);
    final parameters = _validateParameters(aiSkill.parameters, ruleBasedSkill.parameters);

    return Skill(
      id: aiSkill.id,
      name: name,
      kind: kind,
      goal: goal,
      description: description,
      steps: steps,
      constraints: constraints,
      requiredTools: requiredTools,
      userInputs: userInputs,
      createdAt: aiSkill.createdAt,
      category: aiSkill.category,
      sourceSessionId: aiSkill.sourceSessionId,
      sourceSessionTitle: aiSkill.sourceSessionTitle,
      version: aiSkill.version,
      schemaVersion: aiSkill.schemaVersion,
      executableSteps: executableSteps,
      parameters: parameters,
      errorHandling: aiSkill.errorHandling,
    );
  }

  /// Validate name field
  String _validateName(String aiValue, String ruleValue) {
    final trimmed = aiValue.trim();
    
    // Check empty
    if (trimmed.isEmpty) {
      return ruleValue;
    }
    
    // Check length
    if (trimmed.length > 60) {
      return ruleValue;
    }
    
    // Check generic names
    final genericNames = {'draft', 'skill', 'new skill', 'untitled', 'new', 'skill draft', 'ai skill'};
    if (genericNames.contains(trimmed.toLowerCase())) {
      return ruleValue;
    }
    
    // Check for CJK if locale is not Chinese
    if (locale != 'zh' && _hasCJK(trimmed)) {
      // Allow CJK for Thai locale
      if (locale != 'th') {
        return ruleValue;
      }
    }
    
    return trimmed;
  }

  /// Validate kind field
  String _validateKind(String aiValue, String ruleValue) {
    const validKinds = {'knowledge', 'workflow', 'executable'};
    final lower = aiValue.toLowerCase();
    if (validKinds.contains(lower)) {
      return lower;
    }
    return ruleValue;
  }

  /// Validate goal field
  String _validateGoal(String aiValue, String ruleValue) {
    final trimmed = aiValue.trim();
    
    if (trimmed.isEmpty) {
      return ruleValue;
    }
    
    if (trimmed.length > 300) {
      return ruleValue;
    }
    
    // Check for CJK if locale is not Chinese/Thai
    if (locale != 'zh' && locale != 'th' && _hasCJK(trimmed)) {
      return ruleValue;
    }
    
    return trimmed;
  }

  /// Validate description field
  String _validateDescription(String aiValue, String ruleValue) {
    final trimmed = aiValue.trim();
    
    if (trimmed.isEmpty) {
      return ruleValue;
    }
    
    if (trimmed.length > 200) {
      return ruleValue;
    }
    
    // Check if duplicate of goal (will be checked at skill level)
    // Check for CJK if locale is not Chinese/Thai
    if (locale != 'zh' && locale != 'th' && _hasCJK(trimmed)) {
      return ruleValue;
    }
    
    return trimmed;
  }

  /// Validate steps array
  List<String> _validateSteps(List<String> aiSteps, List<String> ruleSteps, String kind) {
    // For executable kind, steps are in executableSteps not steps
    if (kind == 'executable') {
      return ruleSteps;
    }
    
    if (aiSteps.isEmpty) {
      return ruleSteps;
    }
    
    final validated = <String>[];
    for (final step in aiSteps) {
      final trimmed = step.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.length > 150) continue;
      
      // Check for action verb (simple heuristic)
      if (!_hasActionVerb(trimmed)) continue;
      
      validated.add(trimmed);
      if (validated.length >= 8) break;
    }
    
    return validated.isEmpty ? ruleSteps : validated;
  }

  /// Validate constraints array
  List<String> _validateConstraints(List<String> aiConstraints, List<String> ruleConstraints) {
    if (aiConstraints.isEmpty) {
      return ruleConstraints;
    }
    
    final validated = aiConstraints
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty && c.length <= 200)
        .toList();
    
    return validated.isEmpty ? ruleConstraints : validated;
  }

  /// Validate required tools
  List<String> _validateRequiredTools(List<String> aiTools, List<String> ruleTools) {
    const validTools = {'bash', 'edit', 'web_fetch', 'read', 'write', 'search', 'present'};
    
    if (aiTools.isEmpty) {
      return ruleTools;
    }
    
    final validated = aiTools
        .map((t) => t.trim().toLowerCase())
        .where(validTools.contains)
        .toList();
    
    return validated.isEmpty ? ruleTools : validated;
  }

  /// Validate user inputs
  List<SkillInput> _validateUserInputs(List<SkillInput> aiInputs, List<SkillInput> ruleInputs) {
    if (aiInputs.isEmpty) {
      return ruleInputs;
    }
    
    final validated = <SkillInput>[];
    final seenKeys = <String>{};
    
    for (final input in aiInputs) {
      final key = input.key.trim();
      if (key.isEmpty) continue;
      if (seenKeys.contains(key)) continue;
      if (key.length > 64) continue;
      
      final label = input.label.trim();
      if (label.isEmpty) continue;
      if (label.length > 100) continue;
      
      final hint = input.hint.trim();
      if (hint.isEmpty) continue;
      if (hint.length > 200) continue;
      
      validated.add(SkillInput(
        key: key,
        label: label,
        hint: hint,
        type: input.type,
        required: input.required,
        defaultValue: input.defaultValue,
        options: input.options,
      ));
      seenKeys.add(key);
    }
    
    return validated.isEmpty ? ruleInputs : validated;
  }

  /// Validate executable steps
  List<SkillStep>? _validateExecutableSteps(List<SkillStep>? aiSteps, List<SkillStep>? ruleSteps) {
    if (aiSteps == null || aiSteps.isEmpty) {
      return ruleSteps;
    }
    
    final validated = <SkillStep>[];
    for (final step in aiSteps) {
      if (step.description.trim().isEmpty) continue;
      if (step.description.length > 150) continue;
      if (!_hasActionVerb(step.description)) continue;
      
      // Validate tool
      String? tool;
      if (step.tool != null) {
        const validTools = {'bash', 'edit', 'web_fetch', 'read', 'write', 'search', 'present'};
        if (validTools.contains(step.tool!.toLowerCase())) {
          tool = step.tool!.toLowerCase();
        }
      }
      
      validated.add(SkillStep(
        id: step.id,
        description: step.description.trim(),
        mode: step.mode,
        tool: tool,
        args: step.args,
        order: step.order,
      ));
      
      if (validated.length >= 8) break;
    }
    
    return validated.isEmpty ? ruleSteps : validated;
  }

  /// Validate parameters
  List<SkillParameter>? _validateParameters(List<SkillParameter>? aiParams, List<SkillParameter>? ruleParams) {
    if (aiParams == null || aiParams.isEmpty) {
      return ruleParams;
    }
    
    final validated = <SkillParameter>[];
    final seenKeys = <String>{};
    
    for (final param in aiParams) {
      final key = param.key.trim();
      if (key.isEmpty) continue;
      if (seenKeys.contains(key)) continue;
      if (key.length > 64) continue;
      
      final label = param.label.trim();
      if (label.isEmpty) continue;
      if (label.length > 200) continue;
      
      validated.add(SkillParameter(
        key: key,
        label: label,
        type: param.type,
        required: param.required,
        defaultValue: param.defaultValue,
        options: param.options,
        bindToStep: param.bindToStep,
        bindToTool: param.bindToTool,
        template: param.template,
      ));
      seenKeys.add(key);
    }
    
    return validated.isEmpty ? ruleParams : validated;
  }

  /// Check if text contains CJK characters
  bool _hasCJK(String text) {
    final cjkRegex = RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af]');
    return cjkRegex.hasMatch(text);
  }

  /// Check if text has an action verb (simple heuristic)
  bool _hasActionVerb(String text) {
    final actionVerbs = {
      'create', 'make', 'build', 'generate', 'write', 'read', 'run', 'execute',
      'install', 'update', 'delete', 'remove', 'copy', 'move', 'rename',
      'search', 'find', 'fetch', 'get', 'download', 'upload', 'sync',
      'test', 'check', 'verify', 'validate', 'lint', 'format', 'compile',
      'deploy', 'push', 'pull', 'commit', 'merge', 'branch', 'checkout',
      'analyze', 'parse', 'extract', 'transform', 'convert', 'process',
      'configure', 'setup', 'init', 'initialize', 'start', 'stop', 'restart',
      'สร้าง', 'เขียน', 'รัน', 'ติดตั้ง', 'อัปเดต', 'ลบ', 'คัดลอก', 'ย้าย', 'ค้นหา',
      'ดาวน์โหลด', 'อัปโหลด', 'ทดสอบ', 'ตรวจสอบ', 'วิเคราะห์', 'แปลง', 'ประมวลผล',
      'ตั้งค่า', 'เริ่ม', 'หยุด', 'รีสตาร์ท',
      '创建', '编写', '运行', '安装', '更新', '删除', '复制', '移动', '搜索',
      '下载', '上传', '测试', '检查', '分析', '转换', '处理', '配置', '开始', '停止', '重启'
    };
    
    final words = text.toLowerCase().split(RegExp(r'[\s\p{P}]+'));
    return words.any(actionVerbs.contains);
  }
}