
abstract class Result {
  final dynamic value;
  final ErrInfo? error;

  bool get succeed;
  bool get failed;

  const Result({this.value, this.error});

}

class Succeed extends Result {
  @override
  bool get succeed => true;
  @override
  bool get failed => false;

  const Succeed([dynamic value]) : super(value: value);

}

class Fail extends Result {
  @override
  bool get succeed => false;
  @override
  bool get failed => true;

  const Fail(ErrInfo error) : super(error: error);

}

abstract class ErrInfo {
  const ErrInfo();
}

// General failures
class PlatformFailure extends ErrInfo {
  @override
  String toString() => "PlatformFailure";
  const PlatformFailure();
}

class IOFailure extends ErrInfo {
  @override
  String toString() => "IOFailure";
  const IOFailure();
}

class AlreadExists extends ErrInfo {
  @override
  String toString() => "AlreadyExists";
  const AlreadExists();
}

class ErrMsg extends ErrInfo {
  final String msg;
  @override
  String toString() => msg;

  ErrMsg(this.msg);
}
