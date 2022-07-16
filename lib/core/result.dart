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
  Success? get successValue;
  Failure? get failureValue;
  void fold(void Function(Success) successHandler,
      void Function(Failure) failureHandler);
}

class Succeed<S, F> extends Result<S, F> {
  S value;
  Succeed(this.value);

  @override
  isSuccess() => true;

  @override
  isFailure() => false;

  @override
  S get successValue => value;

  @override
  F? get failureValue => null;

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
  S? get successValue => null;

  @override
  F get failureValue => value;

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
