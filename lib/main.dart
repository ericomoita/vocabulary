import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocabulary Memorizer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
      routes: {
        '/cadastro': (context) => CadastroScreen(),
        '/aprendizado': (context) => LearningScreen(),
        '/editWords': (context) => EditWordsScreen(),
        '/importWords': (context) => ImportWordsScreen(), // New route
      },
    );
  }
}


class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vocabulary Memorizer'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: Text('Cadastro de Palavras'),
              onPressed: () {
                Navigator.pushNamed(context, '/cadastro');
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Modo de Aprendizado'),
              onPressed: () {
                Navigator.pushNamed(context, '/aprendizado');
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Edit Words'),
              onPressed: () {
                Navigator.pushNamed(context, '/editWords');
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Import Words'),
              onPressed: () {
                Navigator.pushNamed(context, '/importWords');
              },
            ),
          ],
        ),
      ),
    );
  }
}


class CadastroScreen extends StatefulWidget {
  @override
  _CadastroScreenState createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  void _saveWord() async {
    if (_formKey.currentState!.validate()) {
      String wordText = _wordController.text.trim();
      String translationText = _translationController.text.trim();
      // Create a new word with an initial score of 0.
      Word newWord = Word(
        word: wordText,
        translation: translationText,
        score: 0,
      );
      await DBHelper.instance.insertWord(newWord);
      ScaffoldMessenger.of(this.context)
          .showSnackBar(SnackBar(content: Text('Word added successfully!')));
      _wordController.clear();
      _translationController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastro de Palavras'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
          controller: _wordController,
          decoration: InputDecoration(labelText: 'Word'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a word';
            }
            return null;
          },
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              if (newValue.text.isNotEmpty) {
                String newText = newValue.text[0].toUpperCase() + newValue.text.substring(1);
                return newValue.copyWith(text: newText);
              }
              return newValue;
            }),
          ],
              ),
              TextFormField(
          controller: _translationController,
          decoration: InputDecoration(labelText: 'Translation'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a translation';
            }
            return null;
          },
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              if (newValue.text.isNotEmpty) {
                String newText = newValue.text[0].toUpperCase() + newValue.text.substring(1);
                return newValue.copyWith(text: newText);
              }
              return newValue;
            }),
          ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
          child: Text('Save'),
          onPressed: _saveWord,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LearningScreen extends StatefulWidget {
  @override
  _LearningScreenState createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _showTranslation = false;
  bool _isButtonDisabled = false;
  FlutterTts flutterTts = FlutterTts();
  Timer? _navigationTimer;
  double _dragDistance = 0.0; // For swipe detection

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    List<Word> words = await DBHelper.instance.getPendingWords();
    setState(() {
      _words = words;
      _currentIndex = 0;
    });
    if (_words.isNotEmpty) {
      _speakCurrentWord();
    }
  }

  Future<void> _speakCurrentWord() async {
    if (_words.isNotEmpty && _currentIndex < _words.length) {
      await flutterTts.setLanguage("en-US");
      await flutterTts.speak(_words[_currentIndex].word);
    }
  }

  // Function for SIM and NÃO buttons
  void _handleAnswer(bool remember) async {
    if (_words.isEmpty || _isButtonDisabled) return;

    setState(() {
      _isButtonDisabled = true;
      _showTranslation = true;
    });

    Word currentWord = _words[_currentIndex];
    if (remember) {
      currentWord.score += 1;
    } else {
      currentWord.score -= 1;
    }

    await DBHelper.instance.updateWord(currentWord);

    _navigationTimer?.cancel();
    _navigationTimer = Timer(Duration(seconds: 2), () {
      _goToNextWord();
    });
  }

  // Function for revealing translation via tap (no score update)
  void _revealTranslation(bool onlyShow) {
    if (!_showTranslation) {
      setState(() {
        _showTranslation = true;
        _isButtonDisabled = true;
      });
      _navigationTimer?.cancel();
      _navigationTimer = Timer(Duration(seconds: 2), () {
        if (!onlyShow) {
        _goToNextWord();
        }
      });
    }
  }

  void _goToNextWord() {
    _navigationTimer?.cancel();
    setState(() {
      _showTranslation = false;
      _isButtonDisabled = false;
      if (_words[_currentIndex].score >= 5) {
        _words.removeAt(_currentIndex);
        if (_words.isEmpty) return;
        _currentIndex = _currentIndex % _words.length;
      } else {
        _currentIndex = (_currentIndex + 1) % _words.length;
      }
    });
    _speakCurrentWord();
  }

  void _goToPreviousWord() {
    _navigationTimer?.cancel();
    setState(() {
      _showTranslation = false;
      _isButtonDisabled = false;
      _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
    });
    _speakCurrentWord();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Learning Mode'),
        ),
        body: Center(child: Text('No words to learn. Please add some words.')),
      );
    }
    Word currentWord = _words[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Learning Mode'),
      ),
      body: GestureDetector(
        onTap: () => _revealTranslation(true), // Reveal translation when tapping on the screen
        onPanUpdate: (details) {
          _dragDistance += details.delta.dx;
        },
        onPanEnd: (details) {
          if (_dragDistance > 50) {
            _goToPreviousWord();
          } else if (_dragDistance < -50) {
            _goToNextWord();
          }
          _dragDistance = 0.0;
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top area: display word and translation.
              Padding(
  padding: EdgeInsets.only(top: 40, bottom: 20),
  child: Column(
    children: [
      // Wrap the word Text widget with a GestureDetector
      GestureDetector(
          onTap:() => _revealTranslation(true),
  onHorizontalDragUpdate: (details) {
    _dragDistance += details.delta.dx;
  },
  onHorizontalDragEnd: (details) {
    if (_dragDistance > 50) {
      _goToPreviousWord();
    } else if (_dragDistance < -50) {
      _goToNextWord();
    }
    _dragDistance = 0.0;
  },
        child: Text(
          currentWord.word,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
      if (_showTranslation)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Text(
            currentWord.translation,
            style: TextStyle(
              fontSize: 30,
              color: Color.fromARGB(255, 221, 71, 71),
            ),
            textAlign: TextAlign.center,
          ),
        ),
    ],
  ),
),
              Expanded(child: Container()), // Pushes buttons to bottom.
              Text(
                      'Score for this word: ${currentWord.score}',
                      
                    ),
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                      'Word ${_currentIndex + 1} of ${_words.length}',

                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
              ),
              // Bottom area: buttons.
              Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      child: Text('Sim'),
                      onPressed:
                          _isButtonDisabled ? null : () => _handleAnswer(true),
                    ),
                    ElevatedButton(
                      child: Text('Não'),
                      onPressed:
                          _isButtonDisabled ? null : () => _handleAnswer(false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





class Word {
  int? id;
  String word;
  String translation;
  int score;

  Word({
    this.id,
    required this.word,
    required this.translation,
    required this.score,
  });

  factory Word.fromMap(Map<String, dynamic> json) => Word(
        id: json['id'],
        word: json['word'],
        translation: json['translation'],
        score: json['score'],
      );

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'word': word,
      'translation': translation,
      'score': score,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('words.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        translation TEXT NOT NULL,
        score INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertWord(Word word) async {
    final db = await instance.database;
    return await db.insert('words', word.toMap());
  }

  Future<List<Word>> getPendingWords() async {
    final db = await instance.database;
    // Return only words that are not yet memorized (score < 5).
    final result = await db.query('words', where: 'score < ?', whereArgs: [5]);
    return result.map((json) => Word.fromMap(json)).toList();
  }

  // New method: Retrieve all words regardless of score.
  Future<List<Word>> getAllWords() async {
    final db = await instance.database;
    final result = await db.query('words');
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<int> updateWord(Word word) async {
    final db = await instance.database;
    return await db.update('words', word.toMap(), where: 'id = ?', whereArgs: [word.id]);
  }

  Future<int> deleteWord(int id) async {
    final db = await instance.database;
    return await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }
}


class EditWordsScreen extends StatefulWidget {
  @override
  _EditWordsScreenState createState() => _EditWordsScreenState();
}

class _EditWordsScreenState extends State<EditWordsScreen> {
  List<Word> _words = [];

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    List<Word> words = await DBHelper.instance.getAllWords();
    setState(() {
      _words = words;
    });
  }

  void _editWord(Word word) {
    final _wordController = TextEditingController(text: word.word);
    final _translationController = TextEditingController(text: word.translation);
    final _scoreController = TextEditingController(text: word.score.toString());

    showDialog(
      context: this.context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Word'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _wordController,
                  decoration: InputDecoration(labelText: 'Word'),
                ),
                TextField(
                  controller: _translationController,
                  decoration: InputDecoration(labelText: 'Translation'),
                ),
                TextField(
                  controller: _scoreController,
                  decoration: InputDecoration(labelText: 'Score'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
             ElevatedButton(
              child: Text('Delete'),
              onPressed: () async {
                await DBHelper.instance.deleteWord(word.id!);
                Navigator.of(context).pop();
                _loadWords();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
            ElevatedButton(
              child: Text('Save'),
              onPressed: () async {
                String newWord = _wordController.text.trim();
                String newTranslation = _translationController.text.trim();
                int? newScore = int.tryParse(_scoreController.text.trim());
                if (newWord.isNotEmpty && newTranslation.isNotEmpty && newScore != null) {
                  Word updatedWord = Word(
                    id: word.id,
                    word: newWord,
                    translation: newTranslation,
                    score: newScore,
                  );
                  await DBHelper.instance.updateWord(updatedWord);
                  Navigator.of(context).pop();
                  _loadWords();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Words'),
      ),
      body: _words.isEmpty
          ? Center(child: Text('No words found.'))
          : ListView.builder(
              itemCount: _words.length,
              itemBuilder: (context, index) {
                final word = _words[index];
                return ListTile(
                  title: Text(word.word),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Translation: ${word.translation}'),
                      Text('Score: ${word.score}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _editWord(word),
                  ),
                );
              },
            ),
    );
  }
}


class ImportWordsScreen extends StatefulWidget {
  @override
  _ImportWordsScreenState createState() => _ImportWordsScreenState();
}

class _ImportWordsScreenState extends State<ImportWordsScreen> {
  final TextEditingController _importController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

Future<void> _importWords() async {
  final inputText = _importController.text;
  if (inputText.trim().isEmpty) return;

  final lines = inputText.split('\n');
  int importedCount = 0;

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty) continue;
    // Split by semicolon
    final parts = line.split(';');
    if (parts.length != 2) {
      // Optionally log or show an error for incorrect format
      continue;
    }
    final wordText = capitalize(parts[0].trim());
    final translationText = capitalize(parts[1].trim());

    // Create a new Word instance (adjust fields if needed)
    Word newWord = Word(
      word: wordText,
      translation: translationText,
      score: 0, // or rememberCount: 0 if you're using that field
    );

    try {
      await DBHelper.instance.insertWord(newWord);
      importedCount++;
    } catch (e) {
      // Optionally log the error to see what's going wrong
      print("Error inserting word: $e");
    }
  }

  ScaffoldMessenger.of(this.context).showSnackBar(
    SnackBar(content: Text('$importedCount words imported successfully!'))
  );
  _importController.clear();
}


  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import Words'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Paste your words in the format "Word;Translation" (one per line):',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Expanded(
                child: TextFormField(
                  controller: _importController,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Booged;Atolado\nStuff up;Encher o saco\nFiendish;Diabólico',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                child: Text('Import Words'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _importWords();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}