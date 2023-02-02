#import "KbeaconPlugin.h"
#if __has_include(<kbeacon/kbeacon-Swift.h>)
#import <kbeacon/kbeacon-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "kbeacon-Swift.h"
#endif

@implementation KbeaconPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftKbeaconPlugin registerWithRegistrar:registrar];
}
@end
