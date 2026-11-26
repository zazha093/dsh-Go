// Draft Validator for Skill Distillation
//
// Field-level validation of AI-generated skill drafts with rule-based fallback.
// Each field is validated independently; failed fields fall back to rule-based values.

import '../skills/skill_distill.dart';
import '../skills/skill_model.dart';
import '../skills/distill/heuristics.dart';
import '../ui/chat/secret_mask.dart';

/// Configuration for draft validation
class DraftValidatorConfig {
  const DraftValidatorConfig({
    this.locale = 'th',
    this.allowCjk = false,
  });

  final String locale;
  final bool allowCjk;
}

/// Result of field validation
class FieldValidationResult {
  const FieldValidationResult({
    required this.isValid,
    this.errorMessage,
    this.fallbackValue,
  });

  final bool isValid;
  final String? errorMessage;
  final dynamic fallbackValue;
}

/// Validation result for entire draft
class DraftValidationResult {
  const DraftValidationResult({
    required this.validatedSkill,
    required this.fieldResults,
    required this.breadcrumb,
  });

  final Skill validatedSkill;
  final Map<String, FieldValidationResult> fieldResults;
  final String breadcrumb;
}

/// Draft Validator - field-level validation with rule-based fallback
class DraftValidator {
  DraftValidator({
    required DistilledDraft ruleBasedDraft,
    DraftValidatorConfig? config,
  }) : _ruleBasedDraft = ruleBasedDraft,
       _config = config ?? const DraftValidatorConfig();

  final DistilledDraft _ruleBasedDraft;
  final DraftValidatorConfig _config;

  /// Validate AI-generated skill draft field by field
  DraftValidationResult validate(Skill aiSkill) {
    final fieldResults = <String, FieldValidationResult>{};

    // Validate each field
    final validatedName = _validateName(aiSkill.name, fieldResults);
    final validatedGoal = _validateGoal(aiSkill.goal, fieldResults);
    final validatedDescription = _validateDescription(aiSkill.description, fieldResults);
    final validatedSteps = _validateSteps(aiSkill.steps, fieldResults);
    final validatedConstraints = _validateConstraints(aiSkill.constraints, fieldResults);
    final validatedTools = _validateTools(aiSkill.requiredTools, fieldResults);
    final validatedUserInputs = _validateUserInputs(aiSkill.userInputs, fieldResults);

    // Build validated skill using validated fields + rule-based fallbacks
    final validatedSkill = Skill(
      id: aiSkill.id,
      name: validatedName,
      goal: validatedGoal,
      description: validatedDescription,
      steps: validatedSteps,
      constraints: validatedConstraints,
      requiredTools: validatedTools,
      userInputs: validatedUserInputs,
      createdAt: aiSkill.createdAt,
      category: aiSkill.category,
      kind: aiSkill.kind,
      schemaVersion: aiSkill.schemaVersion,
      executableSteps: aiSkill.executableSteps,
      parameters: aiSkill.parameters,
      errorHandling: aiSkill.errorHandling,
      sourceSessionId: aiSkill.sourceSessionId,
      sourceSessionTitle: aiSkill.sourceSessionTitle,
    );

    // Generate breadcrumb
    final aiFields = fieldResults.values.where((r) => r.isValid).length;
    final fallbackFields = fieldResults.values.where((r) => !r.isValid).length;
    final breadcrumb = 'ai:ok (fields: ai=$aiFields, fallback=$fallbackFields)';

    return DraftValidationResult(
      validatedSkill: validatedSkill,
      fieldResults: fieldResults,
      breadcrumb: breadcrumb,
    );
  }

  /// Validate name field
  String _validateName(String value, Map<String, FieldValidationResult> results) {
    final trimmed = value.trim();
    
    // Check length
    if (trimmed.length > 60) {
      results['name'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Name exceeds 60 characters',
        fallbackValue: _ruleBasedDraft.name,
      );
      return _ruleBasedDraft.name ?? 'Unnamed Skill';
    }
    
    // Check for generic names
    final genericNames = ['script', 'code', 'result', 'skill', 'draft', 'untitled', 'new skill', 'สคริปต์', 'โค้ด', 'ผลลัพธ์'];
    if (genericNames.any((g) => trimmed.toLowerCase() == g)) {
      results['name'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Name is too generic',
        fallbackValue: _ruleBasedDraft.name,
      );
      return _ruleBasedDraft.name ?? 'Unnamed Skill';
    }
    
    // Check CJK
    if (!_config.allowCjk && _hasCjk(trimmed)) {
      results['name'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Name contains CJK characters (locale != zh)',
        fallbackValue: _ruleBasedDraft.name,
      );
      return _ruleBasedDraft.name ?? 'Unnamed Skill';
    }
    
    // Check secrets
    if (_hasSecrets(trimmed)) {
      results['name'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Name contains potential secrets',
        fallbackValue: _ruleBasedDraft.name,
      );
      return _ruleBasedDraft.name ?? 'Unnamed Skill';
    }
    
    results['name'] = const FieldValidationResult(isValid: true);
    return trimmed;
  }

  /// Validate goal field
  String _validateGoal(String value, Map<String, FieldValidationResult> results) {
    final trimmed = value.trim();
    
    // Check length
    if (trimmed.length > 300) {
      results['goal'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Goal exceeds 300 characters',
        fallbackValue: _ruleBasedDraft.goal,
      );
      return _ruleBasedDraft.goal ?? 'Achieve the described task';
    }
    
    // Check CJK
    if (!_config.allowCjk && _hasCjk(trimmed)) {
      results['goal'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Goal contains CJK characters (locale != zh)',
        fallbackValue: _ruleBasedDraft.goal,
      );
      return _ruleBasedDraft.goal ?? 'Achieve the described task';
    }
    
    // Check secrets
    if (_hasSecrets(trimmed)) {
      results['goal'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Goal contains potential secrets',
        fallbackValue: _ruleBasedDraft.goal,
      );
      return _ruleBasedDraft.goal ?? 'Achieve the described task';
    }
    
    results['goal'] = const FieldValidationResult(isValid: true);
    return trimmed;
  }

  /// Validate description field
  String _validateDescription(String value, Map<String, FieldValidationResult> results) {
    final trimmed = value.trim();
    
    // Check length
    if (trimmed.length > 200) {
      results['description'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Description exceeds 200 characters',
        fallbackValue: _ruleBasedDraft.description,
      );
      return _ruleBasedDraft.description ?? 'Skill distilled from chat';
    }
    
    // Check CJK
    if (!_config.allowCjk && _hasCjk(trimmed)) {
      results['description'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Description contains CJK characters (locale != zh)',
        fallbackValue: _ruleBasedDraft.description,
      );
      return _ruleBasedDraft.description ?? 'Skill distilled from chat';
    }
    
    // Check secrets
    if (_hasSecrets(trimmed)) {
      results['description'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Description contains potential secrets',
        fallbackValue: _ruleBasedDraft.description,
      );
      return _ruleBasedDraft.description ?? 'Skill distilled from chat';
    }
    
    results['description'] = const FieldValidationResult(isValid: true);
    return trimmed;
  }

  /// Validate steps field
  List<String> _validateSteps(List<String> value, Map<String, FieldValidationResult> results) {
    // Check max steps
    if (value.length > 8) {
      results['steps'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Too many steps (max 8)',
        fallbackValue: _ruleBasedDraft.steps?.map((s) => s.title).toList(),
      );
      return _ruleBasedDraft.steps?.map((s) => s.title).take(8).toList() ?? [];
    }
    
    final validatedSteps = <String>[];
    var hasError = false;
    
    for (int i = 0; i < value.length; i++) {
      final step = value[i].trim();
      
      // Check length
      if (step.length > 150) {
        hasError = true;
        break;
      }
      
      // Check for leading symbols
      if (step.startsWith(RegExp(r'^[\s\-\*\d\.\)]+'))) {
        hasError = true;
        break;
      }
      
      // Check CJK
      if (!_config.allowCjk && _hasCjk(step)) {
        hasError = true;
        break;
      }
      
      // Check secrets
      if (_hasSecrets(step)) {
        hasError = true;
        break;
      }
      
      validatedSteps.add(step);
    }
    
    if (hasError) {
      results['steps'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Steps validation failed',
        fallbackValue: _ruleBasedDraft.steps?.map((s) => s.title).toList(),
      );
      return _ruleBasedDraft.steps?.map((s) => s.title).toList() ?? [];
    }
    
    results['steps'] = const FieldValidationResult(isValid: true);
    return validatedSteps;
  }

  /// Validate constraints field
  List<String> _validateConstraints(List<String> value, Map<String, FieldValidationResult> results) {
    final validatedConstraints = <String>[];
    var hasError = false;
    
    for (final constraint in value) {
      final trimmed = constraint.trim();
      
      // Check CJK
      if (!_config.allowCjk && _hasCjk(trimmed)) {
        hasError = true;
        break;
      }
      
      // Check secrets
      if (_hasSecrets(trimmed)) {
        hasError = true;
        break;
      }
      
      validatedConstraints.add(trimmed);
    }
    
    if (hasError) {
      results['constraints'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Constraints validation failed',
        fallbackValue: _ruleBasedDraft.constraints,
      );
      return _ruleBasedDraft.constraints ?? [];
    }
    
    results['constraints'] = const FieldValidationResult(isValid: true);
    return validatedConstraints;
  }

  /// Validate tools field
  List<String> _validateTools(List<String> value, Map<String, FieldValidationResult> results) {
    final validatedTools = <String>[];
    var hasError = false;
    
    for (final tool in value) {
      final trimmed = tool.trim();
      
      // Check CJK
      if (!_config.allowCjk && _hasCjk(trimmed)) {
        hasError = true;
        break;
      }
      
      // Check secrets
      if (_hasSecrets(trimmed)) {
        hasError = true;
        break;
      }
      
      validatedTools.add(trimmed);
    }
    
    if (hasError) {
      results['tools'] = FieldValidationResult(
        isValid: false,
        errorMessage: 'Tools validation failed',
        fallbackValue: _ruleBasedDraft.tools,
      );
      return _ruleBasedDraft.tools ?? [];
    }
    
    results['tools'] = const FieldValidationResult(isValid: true);
    return validatedTools;
  }

  /// Validate user inputs field
  List<SkillInput> _validateUserInputs(List<SkillInput> value, Map<String, FieldValidationResult> results) {
    // For now, just pass through - more complex validation can be added later
    results['userInputs'] = const FieldValidationResult(isValid: true);
    return value;
  }

  /// Check if string contains CJK characters
  bool _hasCjk(String text) {
    // CJK Unicode ranges: \u4e00-\u9fff (CJK Unified Ideographs)
    // \u3040-\u309f (Hiragana), \u30a0-\u30ff (Katakana)
    // \uac00-\ud7af (Hangul)
    final cjkRegex = RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af]');
    return cjkRegex.hasMatch(text);
  }

  /// Check if string contains potential secrets
  bool _hasSecrets(String text) {
    // Use secret_mask to detect secrets
    final findings = findSecrets(text);
    return findings.isNotEmpty;
  }
}