import 'package:equatable/equatable.dart';

abstract class Result {
  final dynamic value;
  final ErrInfo? error;

  bool get succeed;
  bool get failed;

  Result({this.value, this.error});
}

class Succeed extends Result {
  @override
  bool get succeed => true;
  @override
  bool get failed => false;

  Succeed([dynamic value]) : super(value: value);
}

class Fail extends Result {
  @override
  bool get succeed => false;
  @override
  bool get failed => true;

  Fail(ErrInfo error) : super(error: error);
}

abstract class ErrInfo extends Equatable {
  @override
  List<Object> get props => [];
}

// General failures
class PlatformFailure extends ErrInfo {
  @override
  String toString() => "PlatformFailure";
}

class IOFailure extends ErrInfo {
  @override
  String toString() => "IOFailure";
}

class AlreadExists extends ErrInfo {
  @override
  String toString() => "AlreadyExists";
}

class ErrMsg extends ErrInfo {
  final String msg;
  @override
  String toString() => msg;

  ErrMsg(this.msg);
}
