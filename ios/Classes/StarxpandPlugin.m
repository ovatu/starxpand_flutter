#import "StarXpandPlugin.h"
#if __has_include(<starxpand/starxpand-Swift.h>)
#import <starxpand/starxpand-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "starxpand-Swift.h"
#endif

@implementation StarXpandPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftStarXpandPlugin registerWithRegistrar:registrar];
}
@end
