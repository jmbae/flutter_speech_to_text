package io.coderails.flutter_speech_to_text;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.util.Log;

import java.util.ArrayList;
import java.util.Locale;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * FlutterSpeechToTextPlugin
 */
public class FlutterSpeechToTextPlugin implements MethodCallHandler, RecognitionListener {
    private static final String LOG_TAG = "FlutterSTTPlugin";

    private SpeechRecognizer speech;
    private MethodChannel speechChannel;
    private String transcription = "";
    private Intent recognizerIntent;
    private Activity activity;

    private FlutterSpeechToTextPlugin(Activity activity, MethodChannel channel) {
        this.speechChannel = channel;
        this.speechChannel.setMethodCallHandler(this);
        this.activity = activity;

        speech = SpeechRecognizer.createSpeechRecognizer(activity.getApplicationContext());
        speech.setRecognitionListener(this);

        recognizerIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_WEB_SEARCH);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3);

        doPermAudio();
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_speech_to_text");
        channel.setMethodCallHandler(new FlutterSpeechToTextPlugin(registrar.activity(), channel));
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);

            case "speech.activate":
                // FIXME => Dummy activation verification : we assume that speech recognition
                // permission
                // is declared in the manifest and accepted during installation ( AndroidSDK 21-
                // )
                Locale locale = activity.getResources().getConfiguration().locale;
                Log.d(LOG_TAG, "Current Locale : " + locale.toString());
                speechChannel.invokeMethod("speech.onCurrentLocale", locale.toString());
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale);
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale);
                result.success(true);
                break;
            case "speech.config":
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, getLocale(call.arguments.toString()));
                recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, getLocale(call.arguments.toString()));
                result.success(true);
                break;
            case "speech.listen":
                speech.startListening(recognizerIntent);
                result.success(true);
                break;
            case "speech.cancel":
                speech.cancel();
                result.success(false);
                break;
            case "speech.stop":
                speech.stopListening();
                result.success(true);
                break;
            case "speech.destroy":
                speech.cancel();
                speech.destroy();
                result.success(true);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private Locale getLocale(String code) {
        String[] localeParts = code.split("_");
        return new Locale(localeParts[0], localeParts[1]);
    }

    @Override
    public void onReadyForSpeech(Bundle params) {
        Log.d(LOG_TAG, "onReadyForSpeech");
        speechChannel.invokeMethod("speech.onSpeechAvailability", true);
    }

    @Override
    public void onBeginningOfSpeech() {
        Log.d(LOG_TAG, "onRecognitionStarted");
        transcription = "";
        speechChannel.invokeMethod("speech.onRecognitionStarted", null);
    }

    @Override
    public void onRmsChanged(float rmsdB) {
        Log.d(LOG_TAG, "onRmsChanged : " + rmsdB);
    }

    @Override
    public void onBufferReceived(byte[] buffer) {
        Log.d(LOG_TAG, "onBufferReceived");
    }

    @Override
    public void onEndOfSpeech() {
        Log.d(LOG_TAG, "onEndOfSpeech");
        speechChannel.invokeMethod("speech.onRecognitionComplete", transcription);
    }

    @Override
    public void onError(int error) {
        Log.d(LOG_TAG, "onError : " + error);
        speechChannel.invokeMethod("speech.onSpeechAvailability", false);
        speechChannel.invokeMethod("speech.onError", error);
    }

    @Override
    public void onPartialResults(Bundle partialResults) {
        Log.d(LOG_TAG, "onPartialResults...");
        ArrayList<String> matches = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if (matches != null) {
            transcription = matches.get(0);
        }
        sendTranscription(false);
    }

    @Override
    public void onEvent(int eventType, Bundle params) {
        Log.d(LOG_TAG, "onEvent : " + eventType);
    }

    @Override
    public void onResults(Bundle results) {
        Log.d(LOG_TAG, "onResults...");
        ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if (matches != null) {
            transcription = matches.get(0);
            Log.d(LOG_TAG, "onResults -> " + transcription);
            sendTranscription(true);
        }
        sendTranscription(false);
    }

    private void sendTranscription(boolean isFinal) {
        speechChannel.invokeMethod(isFinal ? "speech.onRecognitionComplete" : "speech.onSpeech", transcription);
    }

    void doPermAudio() {
        int MY_PERMISSIONS_RECORD_AUDIO = 1;

        if (ContextCompat.checkSelfPermission(activity,
                Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {

            ActivityCompat.requestPermissions(activity,
                    new String[]{Manifest.permission.RECORD_AUDIO},
                    MY_PERMISSIONS_RECORD_AUDIO);
        }
    }
}
