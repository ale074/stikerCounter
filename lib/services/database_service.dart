import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sticker_button.dart';
import '../models/button_press.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sticker_counter.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sticker_buttons (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            imagePath TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            size REAL NOT NULL DEFAULT 100.0,
            posX REAL NOT NULL DEFAULT -1,
            posY REAL NOT NULL DEFAULT -1
          )
        ''');

        await db.execute('''
          CREATE TABLE button_presses (
            id TEXT PRIMARY KEY,
            buttonId TEXT NOT NULL,
            pressedAt TEXT NOT NULL,
            FOREIGN KEY (buttonId) REFERENCES sticker_buttons (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE sticker_buttons ADD COLUMN posX REAL NOT NULL DEFAULT -1');
          await db.execute(
              'ALTER TABLE sticker_buttons ADD COLUMN posY REAL NOT NULL DEFAULT -1');
        }
      },
    );
  }

  // --- Sticker Buttons ---

  Future<List<StickerButton>> getAllButtons() async {
    final db = await database;
    final maps = await db.query('sticker_buttons', orderBy: 'createdAt ASC');
    return maps.map((m) => StickerButton.fromMap(m)).toList();
  }

  Future<void> insertButton(StickerButton button) async {
    final db = await database;
    await db.insert('sticker_buttons', button.toMap());
  }

  Future<void> updateButton(StickerButton button) async {
    final db = await database;
    await db.update(
      'sticker_buttons',
      button.toMap(),
      where: 'id = ?',
      whereArgs: [button.id],
    );
  }

  Future<void> deleteButton(String id) async {
    final db = await database;
    await db.delete('button_presses', where: 'buttonId = ?', whereArgs: [id]);
    await db.delete('sticker_buttons', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getButtonCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM sticker_buttons');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- Button Presses ---

  Future<void> recordPress(ButtonPress press) async {
    final db = await database;
    await db.insert('button_presses', press.toMap());
  }

  Future<int> getTotalPressesForButton(String buttonId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM button_presses WHERE buttonId = ?',
      [buttonId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getMonthlyPresses(String buttonId, int year) async {
    final db = await database;
    final presses = await db.query(
      'button_presses',
      where: 'buttonId = ? AND pressedAt LIKE ?',
      whereArgs: [buttonId, '$year%'],
      orderBy: 'pressedAt ASC',
    );

    final Map<String, int> monthly = {};
    for (int m = 1; m <= 12; m++) {
      final key = m.toString().padLeft(2, '0');
      monthly[key] = 0;
    }

    for (final press in presses) {
      final date = DateTime.parse(press['pressedAt'] as String);
      final key = date.month.toString().padLeft(2, '0');
      monthly[key] = (monthly[key] ?? 0) + 1;
    }

    return monthly;
  }

  Future<List<ButtonPress>> getPressesForButton(String buttonId) async {
    final db = await database;
    final maps = await db.query(
      'button_presses',
      where: 'buttonId = ?',
      whereArgs: [buttonId],
      orderBy: 'pressedAt DESC',
    );
    return maps.map((m) => ButtonPress.fromMap(m)).toList();
  }

  Future<Map<String, Map<String, int>>> getAllButtonsMonthlyPresses(
      int year) async {
    final buttons = await getAllButtons();
    final Map<String, Map<String, int>> result = {};

    for (final button in buttons) {
      result[button.id] = await getMonthlyPresses(button.id, year);
    }

    return result;
  }

  Future<int> getTodayPressesForButton(String buttonId) async {
    final db = await database;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM button_presses WHERE buttonId = ? AND pressedAt LIKE ?',
      [buttonId, '$todayStr%'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
