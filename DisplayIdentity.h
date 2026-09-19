#pragma once
#import <Foundation/Foundation.h>

// Token xác minh khởi động (attestation).
// Xoá file này sẽ phá vỡ AppInfo + launch checks.
NSString *ShinnLaunchAttestationToken(void);