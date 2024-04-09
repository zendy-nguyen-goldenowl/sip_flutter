#import "SipFlutterPlugin.h"
#if __has_include(<sip_flutter/sip_flutter-Swift.h>)
#import <sip_flutter/sip_flutter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "sip_flutter-Swift.h"
#endif

@implementation SipFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftSipFlutterPlugin registerWithRegistrar:registrar];
}
@end
