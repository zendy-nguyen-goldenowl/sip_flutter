//
//  SipClient.h
//  sip_flutter
//
//  Created by Catelt on 5/8/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SipCall;
@class SipClient;

/// SIP Events
@protocol SipClientDelegate<NSObject>
@optional
- (void)onWillRegister:(SipClient*)sipSdk;
- (void)onDidRegister:(SipClient*)sipSdk;
- (void)onFailedRegister:(SipClient*)sipSdk;
- (void)onWillUnRegister:(SipClient*)sipSdk;

- (void)onCallOutgoing:(SipCall*)sipCall;
- (void)onCallIncoming:(SipCall*)sipCall;
- (void)onCallRinging:(SipCall*)sipCall;
- (void)onCallProcess:(SipCall*)sipCall;
- (void)onCallEstablished:(SipCall*)sipCall;
- (void)onCallClosed:(SipCall*)sipCall;
- (void)onCallTransferFailed:(SipCall*)sipCall;
- (void)onCallDtmfStart:(SipCall*)sipCall;
- (void)onCallDtmfEnd:(SipCall*)sipCall;
@end

/// SIP Client
@interface SipClient : NSObject
@property (nonatomic, nonnull) NSString* username;
@property (nonatomic, nonnull) NSString* domain;
@property (nonatomic) NSString* password;
@property (nonatomic) int port;
@property (nonatomic) int regint;

@property (nonatomic) id<SipClientDelegate> delegate;

- (instancetype)initWithUsername:(NSString*)username domain:(NSString*)domain;

- (int)start;
- (void)stop;

- (int)registry;
- (void)unregister;
- (bool)isRegistered;

- (SipCall*)makeCall:(NSString*)uri;
@end

/// SIP Call
@interface SipCall : NSObject
@property (nonatomic, readonly) NSString* remoteUri;

- (void)answer;
- (void)hangup:(unsigned short)statusCode reason:(NSString*)reason;
- (void)hold;
- (void)resume;
- (bool)isMicMuted;
- (void)setMicMuted:(bool)isMute;

@end

NS_ASSUME_NONNULL_END
