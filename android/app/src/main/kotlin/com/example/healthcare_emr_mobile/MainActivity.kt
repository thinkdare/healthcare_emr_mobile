package com.example.healthcare_emr_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's Android implementation requires a FragmentActivity host for
// its biometric prompt — plain FlutterActivity doesn't support it.
class MainActivity : FlutterFragmentActivity()
