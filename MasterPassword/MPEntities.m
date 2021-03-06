//
//  MPElementEntities.m
//  MasterPassword-iOS
//
//  Created by Maarten Billemont on 31/05/12.
//  Copyright (c) 2012 Lyndir. All rights reserved.
//

#import "MPEntities.h"
#import "MPAppDelegate.h"

@implementation NSManagedObject (MP)

- (BOOL)saveContext {

    NSError *error;
    NSManagedObjectContext *moc = [self managedObjectContext];
    if (![moc save:&error]) {
        err(@"While saving %@: %@", NSStringFromClass([self class]), error);
        return NO;
    }
    if (![moc.parentContext save:&error]) {
        err(@"While saving parent %@: %@", NSStringFromClass([self class]), error);
        return NO;
    }

    return YES;
}

@end

@implementation MPElementEntity (MP)

- (MPElementType)type {

    // Some people got elements with type == 0.
    MPElementType type = (MPElementType)[self.type_ unsignedIntegerValue];
    if (!type || type == NSNotFound)
        type = [self.user defaultType];
    if (!type || type == NSNotFound)
        type = MPElementTypeGeneratedLong;

    return type;
}

- (void)setType:(MPElementType)aType {

    // Make sure we don't poison our model data with invalid values.
    if (!aType || aType == NSNotFound)
        aType = [self.user defaultType];
    if (!aType || aType == NSNotFound)
        aType = MPElementTypeGeneratedLong;
        
    self.type_ = @(aType);
}

- (NSString *)typeName {

    return [self.algorithm nameOfType:self.type];
}

- (NSString *)typeShortName {

    return [self.algorithm shortNameOfType:self.type];
}

- (NSString *)typeClassName {

    return [self.algorithm classNameOfType:self.type];
}

- (Class)typeClass {

    return [self.algorithm classOfType:self.type];
}

- (NSUInteger)uses {

    return [self.uses_ unsignedIntegerValue];
}

- (void)setUses:(NSUInteger)anUses {

    self.uses_ = @(anUses);
}

- (NSUInteger)version {

    return [self.version_ unsignedIntegerValue];
}

- (void)setVersion:(NSUInteger)version {

    self.version_ = @(version);
}

- (BOOL)requiresExplicitMigration {

    return [self.requiresExplicitMigration_ boolValue];
}

- (void)setRequiresExplicitMigration:(BOOL)requiresExplicitMigration {

    self.requiresExplicitMigration_ = @(requiresExplicitMigration);
}

- (id<MPAlgorithm>)algorithm {

    return MPAlgorithmForVersion(self.version);
}

- (NSUInteger)use {

    self.lastUsed = [NSDate date];
    return ++self.uses;
}

- (id)content {

    MPKey *key = [MPAppDelegate get].key;
    if (!key)
        return nil;

    assert([key.keyID isEqualToData:self.user.keyID]);
    return [self contentUsingKey:key];
}

- (void)setContent:(id)content {

    MPKey *key = [MPAppDelegate get].key;
    if (!key)
        return;

    assert([key.keyID isEqualToData:self.user.keyID]);
    [self setContent:content usingKey:key];
}

- (id)contentUsingKey:(MPKey *)key {

    Throw(@"Content retrieval implementation missing for: %@", [self class]);
}

- (void)setContent:(id)content usingKey:(MPKey *)key {

    Throw(@"Content assignment implementation missing for: %@", [self class]);
}

- (NSString *)exportContent {

    return nil;
}

- (void)importProtectedContent:(NSString *)protectedContent protectedByKey:(MPKey *)contentProtectionKey usingKey:(MPKey *)key {

}

- (void)importClearTextContent:(NSString *)clearContent usingKey:(MPKey *)key {

}

- (NSString *)description {

    return PearlString(@"%@:%@", [self class], [self name]);
}

- (NSString *)debugDescription {

    return PearlString(@"{%@: name=%@, user=%@, type=%d, uses=%ld, lastUsed=%@, version=%ld, loginName=%@, requiresExplicitMigration=%d}",
                       NSStringFromClass([self class]), self.name, self.user.name, self.type, (long)self.uses, self.lastUsed, (long)self.version,
                       self.loginName, self.requiresExplicitMigration);
}

- (BOOL)migrateExplicitly:(BOOL)explicit {

    while (self.version < MPAlgorithmDefaultVersion)
        if ([MPAlgorithmForVersion(self.version + 1) migrateElement:self explicit:explicit])
        inf(@"%@ migration to version: %ld succeeded for element: %@", explicit? @"Explicit": @"Automatic", (long)self.version + 1, self);
        else {
            wrn(@"%@ migration to version: %ld failed for element: %@", explicit? @"Explicit": @"Automatic", (long)self.version + 1, self);
            return NO;
        }

    return YES;
}

@end

@implementation MPElementGeneratedEntity (MP)

- (NSUInteger)counter {

    return [self.counter_ unsignedIntegerValue];
}

- (void)setCounter:(NSUInteger)aCounter {

    self.counter_ = @(aCounter);
}

- (id)contentUsingKey:(MPKey *)key {

    if (!(self.type & MPElementTypeClassGenerated)) {
        err(@"Corrupt element: %@, type: %d is not in MPElementTypeClassGenerated", self.name, self.type);
        return nil;
    }

    if (![self.name length])
        return nil;

    return [self.algorithm generateContentForElement:self usingKey:key];
}


@end

@implementation MPElementStoredEntity (MP)

+ (NSDictionary *)queryForDevicePrivateElementNamed:(NSString *)name {

    return [PearlKeyChain createQueryForClass:kSecClassGenericPassword
                                   attributes:@{(__bridge id)kSecAttrService: @"DevicePrivate",
                                                             (__bridge id)kSecAttrAccount: name}
                                      matches:nil];
}

- (id)contentUsingKey:(MPKey *)key {

    assert(self.type & MPElementTypeClassStored);

    NSData *encryptedContent;
    if (self.type & MPElementFeatureDevicePrivate)
        encryptedContent = [PearlKeyChain dataOfItemForQuery:[MPElementStoredEntity queryForDevicePrivateElementNamed:self.name]];
    else
        encryptedContent = self.contentObject;

    NSData *decryptedContent = nil;
    if ([encryptedContent length])
        decryptedContent = [self decryptContent:encryptedContent usingKey:key];

    if (!decryptedContent)
        return nil;

    return [[NSString alloc] initWithBytes:decryptedContent.bytes length:decryptedContent.length encoding:NSUTF8StringEncoding];
}

- (NSData *)decryptContent:(NSData *)encryptedContent usingKey:(MPKey *)key {

    return [encryptedContent decryptWithSymmetricKey:[key subKeyOfLength:PearlCryptKeySize].keyData padding:YES];
}

- (void)setContent:(id)content usingKey:(MPKey *)key {

    assert(self.type & MPElementTypeClassStored);
    assert([key.keyID isEqualToData:self.user.keyID]);

    NSData *encryptedContent = [[[content description] dataUsingEncoding:NSUTF8StringEncoding]
                                          encryptWithSymmetricKey:[key subKeyOfLength:PearlCryptKeySize].keyData padding:YES];

    if (self.type & MPElementFeatureDevicePrivate) {
        [PearlKeyChain addOrUpdateItemForQuery:[MPElementStoredEntity queryForDevicePrivateElementNamed:self.name]
                                withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                              encryptedContent, (__bridge id)kSecValueData,
                                                              #if TARGET_OS_IPHONE
                                                              (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                              (__bridge id)kSecAttrAccessible,
                                                              #endif
                                                              nil]];
        self.contentObject = nil;
    } else
        self.contentObject = encryptedContent;
}

- (NSString *)exportContent {

    return [self.contentObject encodeBase64];
}

- (void)importProtectedContent:(NSString *)protectedContent protectedByKey:(MPKey *)contentProtectionKey usingKey:(MPKey *)key {

    if ([contentProtectionKey.keyID isEqualToData:key.keyID])
        self.contentObject = [protectedContent decodeBase64];

    else {
        NSString *clearContent = [[NSString alloc] initWithData:[self decryptContent:[protectedContent decodeBase64]
                                                                            usingKey:contentProtectionKey]
         encoding:NSUTF8StringEncoding];

        [self importClearTextContent:clearContent usingKey:key];
    }
}

- (void)importClearTextContent:(NSString *)clearContent usingKey:(MPKey *)key {

    [self setContent:clearContent usingKey:key];
}

@end

@implementation MPUserEntity (MP)

- (NSUInteger)avatar {

    return [self.avatar_ unsignedIntegerValue];
}

- (void)setAvatar:(NSUInteger)anAvatar {

    self.avatar_ = @(anAvatar);
}

- (BOOL)saveKey {

    return [self.saveKey_ boolValue];
}

- (void)setSaveKey:(BOOL)aSaveKey {

    self.saveKey_ = @(aSaveKey);
}

- (MPElementType)defaultType {

    return (MPElementType)[self.defaultType_ unsignedIntegerValue];
}

- (void)setDefaultType:(MPElementType)aDefaultType {

    self.defaultType_ = @(aDefaultType);
}

- (NSString *)userID {

    return [MPUserEntity idFor:self.name];
}

+ (NSString *)idFor:(NSString *)userName {

    return [[userName hashWith:PearlHashSHA1] encodeHex];
}

@end
