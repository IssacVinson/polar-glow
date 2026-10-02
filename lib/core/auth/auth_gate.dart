/// Signed-in routing used by [AuthWrapper]. Extracted so login-shell tests
/// do not need a live Firebase Auth listener.
enum AuthDestination { loading, login, admin, employee, customer }

class AuthGate {
  static AuthDestination destination({
    required bool isLoading,
    required bool signedIn,
    String? role,
  }) {
    if (isLoading) return AuthDestination.loading;
    if (!signedIn) return AuthDestination.login;

    switch ((role ?? 'customer').toLowerCase()) {
      case 'admin':
        return AuthDestination.admin;
      case 'employee':
        return AuthDestination.employee;
      default:
        return AuthDestination.customer;
    }
  }
}
