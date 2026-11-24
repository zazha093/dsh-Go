// Parameter Resolver — simple ${param} substitution for skill execution
//
// Replaces ${paramName} placeholders in step arguments with actual values.
// No template engine, no eval, OWASP SSTI safe.

/// Resolves ${param} placeholders in a value using the provided parameters.
String resolveValue(String value, Map<String, String> params) {
  if (!value.contains('\${')) return value;

  var result = value;
  for (final entry in params.entries) {
    final placeholder = '\${${entry.key}}';
    result = result.replaceAll(placeholder, entry.value);
  }
  return result;
}

/// Recursively resolves ${param} placeholders in a map.
Map<String, dynamic> resolveArgs(Map<String, dynamic> args, Map<String, String> params) {
  final resolved = <String, dynamic>{};

  for (final entry in args.entries) {
    final value = entry.value;
    if (value is String) {
      resolved[entry.key] = resolveValue(value, params);
    } else if (value is Map) {
      // Recursively resolve nested maps
      resolved[entry.key] = resolveArgs(
        value.cast<String, dynamic>(),
        params,
      );
    } else if (value is List) {
      // Resolve strings in lists
      resolved[entry.key] = value.map((v) {
        if (v is String) return resolveValue(v, params);
        if (v is Map) return resolveArgs(v.cast<String, dynamic>(), params);
        return v;
      }).toList();
    } else {
      resolved[entry.key] = value;
    }
  }

  return resolved;
}

/// Resolves ${param} placeholders in a SkillStep's arguments.
SkillStep resolveStep(SkillStep step, Map<String, String> params) {
  return step.copyWith(
    args: resolveArgs(step.args, params),
  );
}

/// Resolves all parameters in a skill's executable steps.
List<SkillStep> resolveSkillSteps(List<SkillStep> steps, Map<String, String> params) {
  return steps.map((step) => resolveStep(step, params)).toList();
}

/// Validates that all required parameters have values.
List<String> validateParameters(List<SkillParameter> parameters, Map<String, String> providedParams) {
  final missing = <String>[];

  for (final param in parameters) {
    if (param.required) {
      final hasValue = providedParams.containsKey(param.key) &&
          providedParams[param.key]!.isNotEmpty;
      if (!hasValue && (param.defaultValue == null || param.defaultValue!.isEmpty)) {
        missing.add(param.key);
      }
    }
  }

  return missing;
}

/// Merges provided parameters with defaults and bindings.
Map<String, String> mergeParameters({
  required List<SkillParameter> parameters,
  required Map<String, String> userProvided,
  Map<String, String>? stepOutputs, // For binding from previous steps
}) {
  final merged = <String, String>{};

  // Start with defaults
  for (final param in parameters) {
    if (param.defaultValue != null && param.defaultValue!.isNotEmpty) {
      merged[param.key] = param.defaultValue!;
    }
  }

  // Apply step output bindings (from previous steps)
  if (stepOutputs != null) {
    merged.addAll(stepOutputs);
  }

  // Override with user-provided values (highest priority)
  merged.addAll(userProvided);

  return merged;
}