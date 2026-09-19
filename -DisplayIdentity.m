#import "DisplayIdentity.h"
#import <CommonCrypto/CommonDigest.h>

// Token attestation = SHA-256(bundleID | seed), lấy 8 byte đầu dạng hex.
// Seed cố định, không chứa URL hay chuỗi nhạy cảm.

static const uint8_t kShinnSeed[] = {
    0x53, 0x68, 0x69, 0x6E, 0x6E, 0x48, 0x34, 0x4B,
    0x32, 0x30, 0x32, 0x36, 0x53, 0x65, 0x63, 0x75,
    0x72, 0x65, 0x4C, 0x61, 0x75, 0x6E, 0x63, 0x68
};

NSString *ShinnLaunchAttestationToken(void) {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier]
        ?: @"com.apple.mobile.MobileHouseArrest";

    NSMutableData *seedData = [NSMutableData dataWithBytes:kShinnSeed
                                                    length:sizeof(kShinnSeed)];
    [seedData appendData:[bid dataUsingEncoding:NSUTF8StringEncoding]];

    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(seedData.bytes, (CC_LONG)seedData.length, hash);

    NSMutableString *hex = [NSMutableString stringWithCapacity:16];
    for (int i = 0; i < 8; i++) {
        [hex appendFormat:@"%02x", hash[i]];
    }
    return [hex copy];
}