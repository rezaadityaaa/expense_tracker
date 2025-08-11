import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import '../models/expense_with_category.dart';
import '../models/category.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'expense_tracker.db');

    // Reset database untuk testing - comment jika tidak diperlukan
    // try {
    //   await databaseFactory.deleteDatabase(path);
    //   print('DatabaseService: Old database deleted successfully');
    // } catch (e) {
    //   print('DatabaseService: No existing database to delete: $e');
    // }

    return await openDatabase(path, version: 3, onCreate: (db, version) async {
      await db.execute('''
          CREATE TABLE users(
            user_id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            full_name TEXT NOT NULL,
            profile_picture TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            last_login TEXT,
            is_active INTEGER DEFAULT 1
          )
        ''');

      await db.execute('''
          CREATE TABLE categories(
            category_id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon TEXT NOT NULL,
            color TEXT NOT NULL,
            description TEXT,
            is_default INTEGER DEFAULT 0,
            created_by INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            is_active INTEGER DEFAULT 1
          )
        ''');

      await db.execute('''
          CREATE TABLE expenses(
            expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
            category_id INTEGER NOT NULL REFERENCES categories(category_id) ON DELETE CASCADE,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            expense_date TEXT NOT NULL,
            payment_method TEXT,
            money_type TEXT DEFAULT 'cash',
            location TEXT,
            receipt_url TEXT,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            is_deleted INTEGER DEFAULT 0
          )
        ''');

      await db.execute('''
          CREATE TABLE budgets(
            budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
            category_id INTEGER REFERENCES categories(category_id) ON DELETE SET NULL,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            period_type TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT,
            is_recurring INTEGER DEFAULT 0,
            alert_threshold REAL DEFAULT 80.0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            is_active INTEGER DEFAULT 1
          )
        ''');

      await db.execute(
          'CREATE INDEX idx_expenses_user_date ON expenses(user_id, expense_date DESC)');
      await db.execute(
          'CREATE INDEX idx_budgets_user_active ON budgets(user_id, is_active)');

      // Data awal untuk 8 kategori
      await db.insert('categories', {
        'name': 'Makanan',
        'icon': '🍔',
        'color': '#ff5252',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('categories', {
        'name': 'Transportasi',
        'icon': '🚗',
        'color': '#2196f3',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('categories', {
        'name': 'Belanja',
        'icon': '🛍️',
        'color': '#4caf50',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('categories', {
        'name': 'Hiburan',
        'icon': '🎬',
        'color': '#9c27b0',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('categories', {
        'name': 'Kesehatan',
        'icon': '🏥',
        'color': '#f44336',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('categories', {
        'name': 'Pendidikan',
        'icon': '📚',
        'color': '#ff9800',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('categories', {
        'name': 'Tagihan',
        'icon': '💳',
        'color': '#795548',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('categories', {
        'name': 'Lainnya',
        'icon': '📦',
        'color': '#607d8b',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Tambahkan user default untuk testing
      await db.insert('users', {
        'user_id': 1,
        'username': 'admin',
        'email': 'reza@gmail.com',
        'password_hash': 'hashed_password_12345678',
        'full_name': 'Administrator',
        'created_at': DateTime.now().toIso8601String(),
        'is_active': 1,
      });
    }, onUpgrade: (db, oldVersion, newVersion) async {
      // Migrasi dari versi 2 ke 3: tambahkan kolom money_type
      if (oldVersion < 3) {
        await db.execute(
            'ALTER TABLE expenses ADD COLUMN money_type TEXT DEFAULT "cash"');
      }
    }, onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    });
  }

  // --- Metode CRUD untuk EXPENSES ---
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpensesByUser(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'expense_date DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<ExpenseWithCategory>> getExpensesByDateRange(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        e.*,
        c.name as category_name
      FROM expenses e
      LEFT JOIN categories c ON e.category_id = c.category_id
      WHERE e.user_id = ? AND e.is_deleted = 0 
        AND e.expense_date >= ? AND e.expense_date <= ?
      ORDER BY e.expense_date DESC
    ''', [1, startDate.toIso8601String(), endDate.toIso8601String()]);

    return List.generate(
        maps.length, (i) => ExpenseWithCategory.fromMap(maps[i]));
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'expense_id = ?',
      whereArgs: [expense.expenseId],
    );
  }

  Future<int> deleteExpense(int expenseId) async {
    final db = await database;
    // Soft delete
    return await db.update(
      'expenses',
      {'is_deleted': 1},
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
  }

  // --- Metode CRUD untuk CATEGORIES ---
  Future<List<Category>> getCategories() async {
    try {
      print('DatabaseService: Starting getCategories()');
      final db = await database;
      print('DatabaseService: Database connection established');

      final List<Map<String, dynamic>> maps = await db.query('categories',
          where: 'is_active = 1', orderBy: 'name ASC');

      print('DatabaseService: Found ${maps.length} category records');
      for (var map in maps) {
        print('  - Category: ${map['name']} (ID: ${map['category_id']})');
      }

      final categories =
          List.generate(maps.length, (i) => Category.fromMap(maps[i]));

      // Jika tidak ada kategori, buat kategori default
      if (categories.isEmpty) {
        print(
            'DatabaseService: No categories found, creating default categories...');
        await _createDefaultCategories();
        print('DatabaseService: Default categories created, re-querying...');
        return await getCategories(); // Recursive call to get newly created categories
      }

      print('DatabaseService: Returning ${categories.length} categories');
      return categories;
    } catch (e) {
      print('DatabaseService: Error getting categories: $e');
      rethrow;
    }
  }

  Future<void> _createDefaultCategories() async {
    try {
      print('DatabaseService: Creating default categories...');
      final db = await database;

      final defaultCategories = [
        {'name': 'Makanan', 'icon': '🍔', 'color': '#ff5252'},
        {'name': 'Transportasi', 'icon': '🚗', 'color': '#2196f3'},
        {'name': 'Belanja', 'icon': '🛍️', 'color': '#4caf50'},
        {'name': 'Hiburan', 'icon': '🎬', 'color': '#9c27b0'},
        {'name': 'Kesehatan', 'icon': '🏥', 'color': '#f44336'},
        {'name': 'Pendidikan', 'icon': '📚', 'color': '#ff9800'},
        {'name': 'Tagihan', 'icon': '💳', 'color': '#795548'},
        {'name': 'Lainnya', 'icon': '📦', 'color': '#607d8b'},
      ];

      for (var category in defaultCategories) {
        final result = await db.insert('categories', {
          ...category,
          'is_default': 1,
          'created_at': DateTime.now().toIso8601String(),
          'is_active': 1,
        });
        print(
            'DatabaseService: Created category ${category['name']} with ID: $result');
      }

      print('DatabaseService: All default categories created successfully');
    } catch (e) {
      print('DatabaseService: Error creating default categories: $e');
      rethrow;
    }
  }

  Future<int> insertCategory(Category category) async {
    try {
      final db = await database;
      return await db.insert('categories', category.toMap());
    } catch (e) {
      print('Error inserting category: $e');
      rethrow;
    }
  }

  // --- Anda bisa menambahkan metode CRUD lain untuk USERS dan BUDGETS di sini ---
}
