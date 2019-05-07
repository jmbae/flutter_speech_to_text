#import <Flutter/Flutter.h>
#import <Speech/Speech.h>
#import <Speech/SFSpeechRecognizer.h>

@interface FlutterSpeechToTextPlugin : NSObject<FlutterPlugin, SFSpeechRecognizerDelegate>
@end
