import 'dart:convert';
import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cart.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
    CREATE TABLE cart_products (
      id $textType,
      category_id $textType,
      name $textType,
      photo $textType,
      price $textType,
      discountPrice $textType,
      vendorID $textType,
      quantity $intType,
      extras_price $textType,
      extras $textType,
      variant_info $textType NULL,
      taxSetting $textType NULL
    )
    ''');
    print('Table cart_products created'); // Debugging
  }

  Future<void> insertCartProduct(CartProductModel product) async {
    log(product.toJson().toString());
    final db = await instance.database;
    await db.insert(
      'cart_products',
      product.toJson()
        ..['variant_info'] = jsonEncode(product.variantInfo)
        ..['extras'] = jsonEncode(product.extras)
        ..['taxSetting'] = jsonEncode(product.taxSetting),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CartProductModel>> fetchCartProducts() async {
    final db = await instance.database;
    final maps = await db.query('cart_products');
    return List.generate(maps.length, (i) {
      return CartProductModel.fromJson(maps[i]);
    });
  }

  Future<void> updateCartProduct(CartProductModel product) async {
    final db = await instance.database;

    final Map<String, dynamic> data = {
      'id': product.id,
      'category_id': product.categoryId,
      'name': product.name,
      'photo': product.photo,
      'price': product.price,
      'discountPrice': product.discountPrice,
      'vendorID': product.vendorID,
      'quantity': product.quantity,
      'extras_price': product.extrasPrice,
      'variant_info': jsonEncode(product.variantInfo ?? {}),
      'extras': jsonEncode(product.extras ?? []),
      'taxSetting': jsonEncode(product.taxSetting ?? []),
    };

    await db.update('cart_products', data, where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteCartProduct(String id) async {
    final db = await instance.database;
    await db.delete('cart_products', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> deleteAllCartProducts() async {
    final db = await database;
    cartItem.clear();
    await db.delete('cart_products');
  }
}
