import 'package:equatable/equatable.dart';

abstract class Result<Success, Failure> {
  // // Success success;
  // // Failure failure;

  // // // Result._();
  // // Result({this.success, this.failure});

  // bool isSuccess() {
  //   return (success != null) && (failure == null);
  // }

  // bool isFailure() {
  //   return (success == null) && (failure != null);
  // }

  // void fold(void Function(Success) sf, void Function(Failure) ff) {
  //   if (success != null) {sf(success);}
  // }

  bool isSuccess();
  bool isFailure();
  void fold(void Function(Success) sf, void Function(Failure) ff);
}

class Succeed<S, F> extends Result<S, F> {
  S value;
  Succeed(this.value);

  @override
  isSuccess() => true;
  @override
  isFailure() => false;
  @override
  void fold(void Function(S) sf, void Function(F) ff) {
    sf(value);
  }
}

class Fail<S, F> extends Result<S, F> {
  F value;
  Fail(this.value);

  @override
  isSuccess() => false;
  @override
  isFailure() => true;
  @override
  void fold(void Function(S) sf, void Function(F) ff) {
    ff(value);
  }
}

class Void {}

abstract class ErrInfo extends Equatable {
  @override
  List<Object> get props => [];
}

// General failures
class PlatformFailure extends ErrInfo {}

class IOFailure extends ErrInfo {}
