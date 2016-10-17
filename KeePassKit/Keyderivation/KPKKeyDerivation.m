//
//  KPKKeyDerivation.m
//  KeePassKit
//
//  Created by Michael Starke on 05/09/16.
//  Copyright © 2016 HicknHack Software GmbH. All rights reserved.
//

#import "KPKKeyDerivation.h"
#import "KPKKeyDerivation_Private.h"
#import "NSUUID+KeePassKit.h"

NSString *const KPKKeyDerivationBenchmarkSeconds = @"KPKKeyDerivationBenchmarkSeconds";

NSString *const KPKArgon2SaltOption             = @"S";
NSString *const KPKArgon2ParallelismOption      = @"P";
NSString *const KPKArgon2MemoryOption           = @"M";
NSString *const KPKArgon2IterationsOption       = @"I";
NSString *const KPKArgon2VersionOption          = @"V";
NSString *const KPKArgon2KeyOption              = @"K";
NSString *const KPKArgon2AssociativeDataOption  = @"A";

NSString *const KPKAESSeedOption                = @"S"; // NSData
NSString *const KPKAESRoundsOption              = @"R"; // uint64_t wrapped in KPKNumber

@implementation KPKKeyDerivation

static NSMutableDictionary *_keyDerivations;

+ (NSDictionary *)defaultParameters {
  return @{};
}

+ (NSUUID *)uuid {
  return [NSUUID nullUUID];
}

+ (void)_registerKeyDerivation:(Class)derivationClass {
  if(![derivationClass isSubclassOfClass:[KPKKeyDerivation class]]) {
    NSAssert(NO, @"%@ is no valid key derivation class", derivationClass);
    return;
  }
  if(!_keyDerivations) {
    _keyDerivations = [[NSMutableDictionary alloc] init];
  }
  NSUUID *uuid = [derivationClass uuid];
  if(!uuid) {
    NSAssert(uuid, @"%@ does not provide a valid uuid", derivationClass);
    return;
  }
  _keyDerivations[uuid] = derivationClass;
}

+ (KPKKeyDerivation *)keyDerivationWithUUID:(NSUUID *)uuid {
  return [self keyDerivationWithUUID:uuid options:@{}];
}

+ (KPKKeyDerivation *)keyDerivationWithUUID:(NSUUID *)uuid options:(NSDictionary *)options {
  return [[self alloc] initWithUUID:uuid options:options];
}

- (void)benchmarkWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSDictionary * _Nonnull))completionHandler {
  NSAssert(NO, @"%@ should not be called on abstract class!", NSStringFromSelector(_cmd));
}

- (NSData *)deriveData:(NSData *)data {
  return [self deriveData:data options:@{}];
}

- (NSData *)deriveData:(NSData *)data options:(NSDictionary *)options {
  NSAssert(NO, @"%@ should not be called on abstract class!", NSStringFromSelector(_cmd));
  return nil;
}

- (KPKKeyDerivation *)initWithUUID:(NSUUID *)uuid {
  self = [self initWithUUID:uuid options:@{}];
  return self;
}

- (KPKKeyDerivation *)initWithUUID:(NSUUID *)uuid options:(NSDictionary *)options {
  self = nil;
  Class keyDerivationClass = _keyDerivations[uuid];
  self = [(KPKKeyDerivation *)[keyDerivationClass alloc] _initWithOptions:options];
  return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (KPKKeyDerivation *)_initWithOptions:(NSDictionary *)options {
  NSAssert(NO, @"%@ should not be called on abstract class!", NSStringFromSelector(_cmd));
  return nil;
}

- (KPKKeyDerivation *)_init {
  self = [super init];
  return self;
}
#pragma clang diagnostic pop

- (instancetype)init {
  self = [self initWithUUID:self.uuid options:@{}];
  self = nil;
  NSAssert(NO, @"%@ should not be called on abstract class!", NSStringFromSelector(_cmd));
  return nil;
}

- (void)randomize {
  NSAssert(NO, @"%@ should not be called on abstract class!", NSStringFromSelector(_cmd));
}

- (NSUUID *)uuid {
  return [self.class uuid];
}

@end
