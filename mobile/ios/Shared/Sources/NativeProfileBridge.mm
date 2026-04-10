#import "NativeProfileBridge.h"

#include "shinsoku/nativecore/c_api.h"

@implementation NativeProfileBridge

+ (nullable NSString *)builtinProfilesJSON {
    const char *raw = shinsoku_mobile_builtin_profiles_json();
    if (raw == nullptr) {
        return nil;
    }

    NSString *value = [NSString stringWithUTF8String:raw];
    shinsoku_mobile_free_string(raw);
    return value;
}

@end
