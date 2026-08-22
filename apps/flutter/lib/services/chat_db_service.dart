import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message.dart';

class ChatDbService {
  static final ChatDbService _instance = ChatDbService._internal();
  factory ChatDbService() => _instance;
  ChatDbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS && !Platform.isLinux && !Platform.isWindows && !Platform.isMacOS)) {
      // In-memory sqlite mock fallback if platform unsupported
      return openDatabase(inMemoryDatabasePath, version: 1, onCreate: _onCreate);
    }
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final path = join(docDir.path, 'meckchat_history.db');
      return await openDatabase(path, version: 1, onCreate: _onCreate);
    } catch (e) {
      debugPrint('Sqflite default open fallback: $e');
      return openDatabase(inMemoryDatabasePath, version: 1, onCreate: _onCreate);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        message_id TEXT PRIMARY KEY,
        sender_device_id TEXT NOT NULL,
        recipient_device_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL
      )
    ''');
  }

  /// Inserts a new chat message into SQLite local database with duplicate protection
  Future<void> insertMessage(ChatMessage msg) async {
    try {
      final db = await database;
      await db.insert(
        'chat_messages',
        msg.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      debugPrint('Error inserting message to SQLite: $e');
    }
  }

  /// Updates status of an existing message (e.g. PENDING -> SENT -> DELIVERED)
  Future<void> updateStatus(String messageId, MessageStatus status) async {
    try {
      final db = await database;
      await db.update(
        'chat_messages',
        {'status': status.name.toUpperCase()},
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('Error updating message status in SQLite: $e');
    }
  }

  /// Retrieves full conversation message history with a peer
  Future<List<ChatMessage>> getConversation(String peerDeviceId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'chat_messages',
        where: 'sender_device_id = ? OR recipient_device_id = ?',
        whereArgs: [peerDeviceId],
        orderBy: 'timestamp ASC',
      );
      return maps.map((m) => ChatMessage.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Error loading conversation from SQLite: $e');
      return [];
    }
  }

  /// Gets all pending offline messages for a specific recipient peer
  Future<List<ChatMessage>> getPendingMessages(String recipientDeviceId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'chat_messages',
        where: 'recipient_device_id = ? AND status = ?',
        whereArgs: [recipientDeviceId, 'PENDING'],
        orderBy: 'timestamp ASC',
      );
      return maps.map((m) => ChatMessage.fromJson(m)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets last message for conversation preview in Chat tab
  Future<ChatMessage?> getLastMessage(String peerDeviceId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'chat_messages',
        where: 'sender_device_id = ? OR recipient_device_id = ?',
        whereArgs: [peerDeviceId],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return ChatMessage.fromJson(maps.first);
      }
    } catch (_) {}
    return null;
  }
}
