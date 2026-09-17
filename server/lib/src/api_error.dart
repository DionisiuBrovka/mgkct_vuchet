class ApiError implements Exception {
  const ApiError(this.status, this.message, {this.code = 'invalid_request'});
  final int status;
  final String message;
  final String code;
}
