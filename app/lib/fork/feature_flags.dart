// Feature flags for fork-specific features
// Controlled via --dart-define at build time

/// Whether the Personal Skills feature is enabled
/// Set via --dart-define=FORK_SKILLS=true
/// Default: false (disabled in production builds)
const bool kEnablePersonalSkills = bool.fromEnvironment('FORK_SKILLS', defaultValue: false);

/// Whether the error handling system is enabled
/// Set via --dart-define=FORK_ERROR_HANDLING=true
/// Default: false (disabled in production builds)
const bool kEnableForkErrorHandling = bool.fromEnvironment('FORK_ERROR_HANDLING', defaultValue: false);

/// Whether breadcrumbs/debug logging is enabled
/// Set via --dart-define=FORK_BREADCRUMBS=true
/// Default: false (disabled in production builds)
const bool kEnableBreadcrumbs = bool.fromEnvironment('FORK_BREADCRUMBS', defaultValue: false);