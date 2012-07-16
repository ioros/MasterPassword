//
//  MPConfig.m
//  MasterPassword
//
//  Created by Maarten Billemont on 02/01/12.
//  Copyright (c) 2012 Lyndir. All rights reserved.
//

@implementation MPiOSConfig
@dynamic sendInfo, helpHidden, userNameHidden, showQuickStart, actionsTipShown, typeTipShown, userNameTipShown;

- (id)init {

    if (!(self = [super init]))
        return self;

    [self.defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO], NSStringFromSelector(@selector(sendInfo)),
                                                   [NSNumber numberWithBool:NO], NSStringFromSelector(@selector(helpHidden)),
                                                   [NSNumber numberWithBool:YES], NSStringFromSelector(@selector(userNameHidden)),
                                                   [NSNumber numberWithBool:YES], NSStringFromSelector(@selector(showQuickStart)),
                                                   @"510296984", NSStringFromSelector(@selector(iTunesID)),
                                                   PearlBoolNot(self.firstRun), NSStringFromSelector(@selector(actionsTipShown)),
                                                   PearlBoolNot(self.firstRun), NSStringFromSelector(@selector(typeTipShown)),
                                                   PearlBool(NO), NSStringFromSelector(@selector(userNameTipShown)),
                                                   nil]];

    return self;
}

+ (MPiOSConfig *)get {

    return (MPiOSConfig *)[super get];
}

@end
