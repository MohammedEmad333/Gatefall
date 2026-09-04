/// Web (and anything without `dart:io`): never a test binding we can detect,
/// and never one we need to.
bool get runningUnderTest => false;
