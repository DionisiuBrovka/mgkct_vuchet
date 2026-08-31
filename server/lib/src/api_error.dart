class ApiError implements Exception {
  const ApiError(this.status, this.message);
  final int status;
  final String message;
}
