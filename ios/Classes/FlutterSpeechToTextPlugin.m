#import "FlutterSpeechToTextPlugin.h"

@interface AuthorizeOperation : NSOperation
@end

@implementation AuthorizeOperation

- (void)main
{
    
}

@end

API_AVAILABLE(ios(10.0))
@interface FlutterSpeechToTextPlugin()
@property(nonatomic, retain) FlutterMethodChannel *speechChannel;

@property (nonatomic) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic) AVAudioEngine *audioEngine;
@property (nonatomic) AVAudioInputNode *inputNode;

@end


@implementation FlutterSpeechToTextPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_speech_to_text"
                                     binaryMessenger:[registrar messenger]];
    FlutterSpeechToTextPlugin* instance = [[FlutterSpeechToTextPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    instance.speechChannel = channel;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"HandleMethod: %@", call.method);
    NSLog(@"arguments: %@", call.arguments);
    
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"speech.activate" isEqualToString:call.method]) {
        NSLocale* locale = [NSLocale localeWithLocaleIdentifier:[call arguments]];
        [self activeRecognitionWithLocale:locale withResult: result];
    } else if ([@"speech.config" isEqualToString:call.method]) {
        NSLog(@"speech.config: %@", [call arguments]);
        NSLocale* locale = [NSLocale localeWithLocaleIdentifier:[call arguments]];
        [self configSpeechRecognitionWithLocale:locale withResult:result];
    } else if ([@"speech.listen" isEqualToString:call.method]) {
        [self startRecognitionWithResult:result];
    } else if ([@"speech.cancel" isEqualToString:call.method]) {
        [self cancelRecognitionWithResult:(FlutterResult)result];
    } else if ([@"speech.stop" isEqualToString:call.method]) {
        [self stopRecognitionWithResult:(FlutterResult)result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available  API_AVAILABLE(ios(10.0)){
    if(self.speechChannel != nil)
        [self.speechChannel invokeMethod:@"speech.onSpeechAvailability" arguments:[NSNumber numberWithBool:available]];
}

- (void)activeRecognitionWithLocale:(NSLocale*)locale withResult: (FlutterResult)result {
    NSLog(@"activeRecognitionWithResult: %@", [locale localeIdentifier]);
    _audioEngine = [[AVAudioEngine alloc] init];
    [self configSpeechRecognitionWithLocale:locale withResult:result];
}

- (void)configSpeechRecognitionWithLocale:(NSLocale*)locale withResult:(FlutterResult) result {
    if (@available(iOS 10.0, *)) {
        NSLog(@"configSpeechRecognitionWithLocale: %@", [locale localeIdentifier]);
        
        _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        _speechRecognizer.delegate = self;
        
        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
            
            switch (status) {
                case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                    result(@NO);
                    return;
                case SFSpeechRecognizerAuthorizationStatusDenied:
                    result(@NO);
                    return;
                case SFSpeechRecognizerAuthorizationStatusRestricted:
                    result(@NO);
                    return;
                case SFSpeechRecognizerAuthorizationStatusAuthorized:
                    break;
            }
            NSOperationQueue *operationQueue = [NSOperationQueue mainQueue];
            [operationQueue addOperationWithBlock:^{
                result(@YES);
                [self.speechChannel invokeMethod:@"speech.onCurrentLocale" arguments:[[NSLocale currentLocale] localeIdentifier]];
            }];
        }];
    } else {
        // Fallback on earlier versions
    }
    
}

- (void)startRecognitionWithResult:(FlutterResult)result {
    if ([_audioEngine isRunning]) {
        NSLog(@"AUDIO ENGINE IS RUNNING");
        [_audioEngine stop];
        [_recognitionRequest endAudio];
        result(@NO);
    } else {
        NSLog(@"AUDIO ENGINE IS WORKING");
        [self startRecording];
        result(@YES);
    }
}

- (void)cancelRecognitionWithResult:(FlutterResult)result {
    if (_recognitionTask != nil) {
        [_recognitionTask cancel];
        _recognitionTask = nil;
        result(@YES);
    } else {
        result(@NO);
    }
}

- (void)stopRecognitionWithResult:(FlutterResult)result {
    if ([_audioEngine isRunning]) {
        NSLog(@"AUDIO ENGINE IS RUNNING");
        [_audioEngine stop];
        [_recognitionRequest endAudio];
    }
    result(@NO);
}

- (void)startRecording {
    if (@available(iOS 10.0, *)) {
        if (_recognitionTask != nil) {
            [_recognitionTask cancel];
            _recognitionTask = nil;
        }
        
        NSError * outError;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        @try {
            [audioSession setCategory:AVAudioSessionCategoryRecord error:&outError];
            [audioSession setMode:AVAudioSessionModeMeasurement error:&outError];
            [audioSession setActive:true withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation  error:&outError];
        } @catch (NSException * e) {
            NSLog(@"audioSession properties weren't set because of an error. %@", e);
        }
        _recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        _inputNode = [_audioEngine inputNode];
        
        if (_inputNode == nil) {
            NSLog(@"Audio engine has no input node");
        }
        if (_recognitionRequest == nil) {
            NSLog(@"Unable to created a SFSpeechAudioBufferRecognitionRequest object");
        }
        _recognitionRequest.shouldReportPartialResults = YES;
        _recognitionTask = [_speechRecognizer recognitionTaskWithRequest:_recognitionRequest
                                                           resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {
                                                               BOOL isFinal = NO;
                                                               if (result != nil) {
                                                                   NSLog(@"speech.onSpeech:%@", result.bestTranscription.formattedString);
                                                                   if (self.speechChannel != nil) {
                                                                       [self.speechChannel invokeMethod:@"speech.onSpeech" arguments:result.bestTranscription.formattedString];
                                                                   }
                                                               }
                                                               NSLog(@"isFinal: %d", result.isFinal);
                                                               isFinal = result.isFinal;
                                                               if (error != nil || isFinal) {
                                                                   [self.audioEngine stop];
                                                                   [self.inputNode removeTapOnBus:0];
                                                                   self.recognitionRequest = nil;
                                                                   self.recognitionTask = nil;
                                                               }
                                                           }];
        
        AVAudioFormat *recordingFormat = [_inputNode outputFormatForBus:0];
        [_inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
            [self.recognitionRequest appendAudioPCMBuffer:buffer];
        }];
        
        [_audioEngine prepare];
        
        @try {
            [_audioEngine startAndReturnError:&outError];
        } @catch (NSException *e) {
            NSLog(@"audioEngine couldn't start because of an error. %@", e);
        }
        
        if (_speechChannel != nil) {
            [_speechChannel invokeMethod:@"speech.onRecognitionStarted" arguments:NULL];
        }
    } else {
        // Fallback on earlier versions
    }
}
@end
