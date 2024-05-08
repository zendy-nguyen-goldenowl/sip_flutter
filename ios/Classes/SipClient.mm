//
//  SipClient.m
//  sip_flutter
//
//  Created by Catelt on 5/8/24.
//

#import "SipClient.h"

#define HAVE__BOOL

#import <baresip/re.h>
#import <baresip/baresip.h>

#include <unordered_map>

static const int kDefaultPort = 5060;

static std::unordered_map<call*, SipCall*> sipCallsCache;

//static dispatch_once_t eventDispatchQueueToken;
//static dispatch_queue_t eventDispatchQueue;

@interface SipCall ()
@property (nonatomic) struct ua *ua;
@property (nonatomic) struct call* call;
@property (nonatomic) int baresipResultCode;

@property (nonatomic) NSString* cachedRemoteUri;
@end

@implementation SipCall
- (instancetype)init {
    self = [super init];
    return self;
}

- (void)deinit {
    sipCallsCache.erase(self.call);
}

- (NSString*)remoteUri {
    return self.cachedRemoteUri;
}

- (void)answer {
    re_thread_enter();
    ua_answer(self.ua, self.call,VIDMODE_OFF);
    re_thread_leave();
}

- (void)hangup:(unsigned short)statusCode reason:(NSString*)reason {
    re_thread_enter();
    ua_hangup(self.ua, self.call, statusCode, [reason cStringUsingEncoding:NSUTF8StringEncoding]);
    re_thread_leave();
}

- (void)hold {
    re_thread_enter();
    call_hold(self.call, true);
    re_thread_leave();
}

- (void)resume {
    re_thread_enter();
    call_hold(self.call, false);
    re_thread_leave();
}

- (bool)isMicMuted {
    return audio_ismuted(call_audio(self.call));
}

- (void)setMicMuted:(bool)isMute {
    re_thread_enter();
    audio_mute(call_audio(self.call),isMute);
    re_thread_leave();
}
@end

@interface SipClient()
@property (nonatomic) struct ua *ua;
@end

static SipCall* getSipCall(struct call *call, SipClient* sipSdk, NSString* remoteUri) {
    SipCall* sipCall;
    auto sipCallCache = sipCallsCache.find(call);
    if (sipCallCache == sipCallsCache.end()) {
        sipCall = [[SipCall alloc] init];
        sipCall.ua = sipSdk.ua;
        sipCall.call = call;
        sipCall.cachedRemoteUri = remoteUri;
    } else {
        sipCall = sipCallCache->second;
    }
    
    return sipCall;
}

static void ua_event_handler(struct ua *ua, enum ua_event ev,
    struct call *call, const char *prm, void *arg)
{
    NSLog(@"ua_event_handler %@ %@", @(ev), @(prm));
    
    SipClient* sipSdk = (__bridge SipClient*)arg;
    SipCall* sipCall = getSipCall(call, sipSdk, @(prm));
    
    switch (ev) {
        case UA_EVENT_REGISTERING: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onWillRegister:)]) {
                    [sipSdk.delegate onWillRegister:sipSdk];
                }
            });
        }
            break;
            
        case UA_EVENT_REGISTER_OK: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onDidRegister:)]) {
                    [sipSdk.delegate onDidRegister:sipSdk];
                }
            });
        }
            break;

        case UA_EVENT_REGISTER_FAIL: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onFailedRegister:)]) {
                    [sipSdk.delegate onFailedRegister:sipSdk];
                }
            });
        }
            break;

        case UA_EVENT_UNREGISTERING: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onWillUnRegister:)]) {
                    [sipSdk.delegate onWillUnRegister:sipSdk];
                }
            });
        }
            break;
            
        case UA_EVENT_CALL_OUTGOING: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallOutgoing:)]) {
                    [sipSdk.delegate onCallOutgoing:sipCall];
                }
            });
        }
            break;
            
        case UA_EVENT_CALL_INCOMING: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallIncoming:)]) {
                    [sipSdk.delegate onCallIncoming:sipCall];
                }
            });
        }
            break;

        case UA_EVENT_CALL_RINGING: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallRinging:)]) {
                    [sipSdk.delegate onCallRinging:sipCall];
                }
            });
        }
            break;
            
        case UA_EVENT_CALL_PROGRESS: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallProcess:)]) {
                    [sipSdk.delegate onCallProcess:sipCall];
                }
            });
        }
            break;
            
        case UA_EVENT_CALL_ESTABLISHED: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallEstablished:)]) {
                    [sipSdk.delegate onCallEstablished:sipCall];
                }
            });
        }
            break;
            
        case UA_EVENT_CALL_CLOSED: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallClosed:)]) {
                    [sipSdk.delegate onCallClosed:sipCall];
                }
            });
        }
            break;
            
        case UA_EVENT_CALL_TRANSFER_FAILED: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallTransferFailed:)]) {
                    [sipSdk.delegate onCallTransferFailed:sipCall];
                }
            });
        }
            break;
            
        case UA_EVENT_CALL_DTMF_START: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallDtmfStart:)]) {
                    [sipSdk.delegate onCallDtmfStart:sipCall];
                }
            });
        }
            break;
            
        case UA_EVENT_CALL_DTMF_END: {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([sipSdk.delegate respondsToSelector:@selector(onCallDtmfEnd:)]) {
                    [sipSdk.delegate onCallDtmfEnd:sipCall];
                }
            });
        }
            break;
    }
}

@implementation SipClient
- (instancetype)initWithUsername:(NSString*)username domain:(NSString*)domain {
    self = [super init];
    if (self) {
        _username = username;
        _domain = domain;
        
        _port = kDefaultPort;
    }
    return self;
}

- (int)start {
    int result = libre_init();
    if (result != 0) {
        return result;
    }
    
    // Initialize dynamic modules.
    mod_init();
    
    NSString *documentDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (documentDirectory != nil) {
        conf_path_set([documentDirectory cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    
    result = conf_configure();
    if (result != 0) {
        return result;
    }
    
    // Init Baresip
    result = baresip_init(conf_config());
    if (result != 0){
        return result;
    }


    // Initialize the SIP stack.
    result = ua_init("SIP", 1, 1, 1);
    if (result != 0) {
        return result;
    }

    // Register UA event handler
    result = uag_event_register(ua_event_handler, (__bridge void *)(self));
    if (result != 0) {
        return result;
    }
    
    result = conf_modules();
    if (result != 0) {
        return result;
    }
    
    // Start the main loop.
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(_run) object:nil];
    [thread start];
    
    return 0;
}

- (void)stop {
    if (!self.ua) {
        return;
    }
    
    mem_deref(self.ua);
    self.ua = nil;
    
    ua_close();
    module_app_unload();
    conf_close();
    baresip_close();

    uag_event_unregister(ua_event_handler);
    
    mod_close();
    
    re_thread_close();

    // Close
    libre_close();
    
    // Check for memory leaks.
    tmr_debug();
    mem_debug();
}

- (int)registry {
    NSString* aor;
    if (self.password) {
        aor = [NSString stringWithFormat:@"sip:%@@%@:%@;auth_pass=%@;stunserver=\"stun:stun.l.google.com:19302\";regq=0.5;pubint=0;regint=%d", self.username,self.domain, @(self.port),self.password,self.regint];
    } else {
        aor = [NSString stringWithFormat:@"sip:%@@%@:%@", self.username, self.domain, @(self.port)];
    }
    
    // Start user agent.
    re_thread_enter();
    int result = ua_alloc(&_ua, [aor cStringUsingEncoding:NSUTF8StringEncoding]);
    re_thread_leave();
    if (result != 0) {
        return result;
    }
    
    re_thread_enter();
    result = ua_register(self.ua);
    re_thread_leave();
    if (result != 0) {
        return result;
    }

    return 0;
}

- (void)unregister {
    re_thread_enter();
    ua_unregister(self.ua);
    re_thread_leave();
}

- (bool)isRegistered {
    return ua_isregistered(self.ua);
}

- (SipCall*)makeCall:(NSString*)uri {
    SipCall* sipCall = [[SipCall alloc] init];
    sipCall.ua = self.ua;
    sipCall.cachedRemoteUri = uri;

    struct call *call;
    re_thread_enter();
    int result = ua_connect(self.ua, &call, nil, [uri cStringUsingEncoding:NSUTF8StringEncoding], VIDMODE_OFF);
    re_thread_leave();
    if (result != 0) {
        sipCall.baresipResultCode = result;
    } else {
        sipCall.call = call;
    }

    return sipCall;
}

-(void)_run {
    // Start the main loop.
    re_main(nil);
}

@end
