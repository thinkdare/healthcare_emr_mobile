import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:sqflite_common_ffi/src/database_factory_ffi_io.dart';
import 'package:sqlite3/open.dart';

// This machine's libsqlite3 package (libsqlite3-0) ships only the versioned
// libsqlite3.so.0, not the unversioned libsqlite3.so symlink that
// package:sqlite3's default Linux loader (DynamicLibrary.open('libsqlite3.so'))
// expects — that symlink normally comes from libsqlite3-dev, which isn't
// installed here. Point the loader at the versioned library directly so
// sqflite_common_ffi-based tests can open a real (in-memory) database instead
// of failing to dlopen at all.
//
// sqflite_common_ffi runs each database call in a background isolate, so the
// override has to be installed there too, not just in this (main) isolate —
// hence rebuilding databaseFactoryFfiImpl with an `ffiInit` callback (which
// sqflite_common_ffi runs inside that isolate) rather than calling
// open.overrideFor directly here. The callback must be a top-level function,
// per sqflite_common_ffi's isolate-boundary requirement.
void _overrideSqlite3LinuxLoader() {
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  _overrideSqlite3LinuxLoader();
  databaseFactoryFfiImpl = createDatabaseFactoryFfiImpl(
    ffiInit: _overrideSqlite3LinuxLoader,
  );
  await testMain();
}
