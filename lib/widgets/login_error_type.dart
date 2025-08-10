enum LoginErrorType {
  invalidCredentials,  // Wrong username/password (401)
  networkError,       // Connectivity issues
  serverError,        // Server problems (5xx)
  authorizationError, // Token/scope issues (403)
  accountLocked,      // Too many attempts (423)
  maintenanceMode,    // Server maintenance (503)
  unknownError        // Catch-all for other errors
}