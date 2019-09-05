import 'package:flutter/material.dart';
import 'package:flutter_speech_to_text/flutter_speech_to_text.dart';

void main() => runApp(MyApp());

const languages = const [
  const Language('한국어', 'ko_KR'),
  const Language('中文', 'cmn-Hans-CN'),
  const Language('日本語', 'ja_JP'),
  const Language('Francais', 'fr_FR'),
  const Language('English', 'en_US'),
  const Language('Pусский', 'ru_RU'),
  const Language('Italiano', 'it_IT'),
  const Language('Español', 'es_ES'),
];

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FlutterSpeechToText _speech;

  bool _speechRecognitionAvailable = false;
  bool _isListening = false;

  String transcription = '';

  Language selectedLang;

  @override
  initState() {
    super.initState();
    selectedLang = languages.first;
    activateSpeechRecognizer();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void activateSpeechRecognizer() async {
    print('_MyAppState.activateSpeechRecognizer... ');
    _speech = FlutterSpeechToText.shared;
    _speech.setAvailabilityHandler(onSpeechAvailability);
    _speech.setCurrentLocaleHandler(onCurrentLocale);
    _speech.setRecognitionStartedHandler(onRecognitionStarted);
    _speech.setRecognitionResultHandler(onRecognitionResult);
    _speech.setRecognitionCompleteHandler(onRecognitionComplete);
    _speech.setErrorHandler(errorHandler);
    var response = await _speech.activate(locale: selectedLang.code);
    setState(() {
      _speechRecognitionAvailable = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('FlutterSpeechToText'),
          actions: [
            new PopupMenuButton<Language>(
              onSelected: _selectLangHandler,
              itemBuilder: (BuildContext context) => _buildLanguagesWidgets,
            )
          ],
        ),
        body: new Padding(
            padding: new EdgeInsets.all(8.0),
            child: new Center(
              child: new Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  new Expanded(
                      child: new Container(
                          padding: const EdgeInsets.all(8.0),
                          color: Colors.grey.shade200,
                          child: Text(transcription, style: TextStyle(color: Colors.black)))),
                  _buildButton(
                    onPressed: _speechRecognitionAvailable && !_isListening
                        ? () => start()
                        : null,
                    label: _isListening
                        ? 'Listening...'
                        : 'Listen (${selectedLang.code})',
                  ),
                  _buildButton(
                    onPressed: _isListening ? () => cancel() : null,
                    label: 'Cancel',
                  ),
                  _buildButton(
                    onPressed: _isListening ? () => stop() : null,
                    label: 'Stop',
                  ),
                ],
              ),
            )),
      ),
    );
  }

  List<CheckedPopupMenuItem<Language>> get _buildLanguagesWidgets => languages
      .map((l) => new CheckedPopupMenuItem<Language>(
            value: l,
            checked: selectedLang == l,
            child: new Text(l.name),
          ))
      .toList();

  void _selectLangHandler(Language lang) {
    setState(() {
      print(lang.code);
      _speech.config(locale: lang.code);
      selectedLang = lang;
    });
  }

  Widget _buildButton({String label, VoidCallback onPressed}) => new Padding(
      padding: new EdgeInsets.all(12.0),
      child: new RaisedButton(
        color: Colors.cyan.shade600,
        onPressed: onPressed,
        child: new Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ));

  void start() async {
    var result = await _speech.listen(locale: selectedLang.code);
    print('_MyAppState.start => result $result');
    setState(() {
      _isListening = result;
    });
  }

  void cancel() async {
    var result = await _speech.cancel();
    setState(() {
      _isListening = result;
    });
  }

  void stop() async {
    var result = await _speech.stop();
    setState(() {
      _isListening = result;
    });
  }

  void onSpeechAvailability(bool result) {
    setState(() {
      return _speechRecognitionAvailable = result;
    });
  }

  void onCurrentLocale(String locale) {
    print('_MyAppState.onCurrentLocale... $locale');

    setState(() {
      selectedLang = languages.firstWhere((l) => l.code == locale);
    });
  }

  void onRecognitionStarted() {
    print('onRecognitionStarted');
    setState(() {
      return _isListening = true;
    });
  }

  void onRecognitionResult(String text) {
    print('onRecognitionResult: $text');
    setState(() {
      return transcription = text;
    });
  }

  void onRecognitionComplete(String text) {
    print('onRecognitionComplete: $text');
    setState(() {
      print(text);
      _isListening = false;
    });
  }

  void errorHandler() => activateSpeechRecognizer();
}
