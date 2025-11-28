import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. CART ITEM MODEL (Now with JSON conversion support)
class CartItem {
  final String id;
  final String serviceId;
  final String title;
  final double price;
  final String imageUrl;
  final String providerId;
  DateTime date;
  TimeOfDay time;
  String serviceType;
  int quantity;

  CartItem({
    required this.id,
    required this.serviceId,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.providerId,
    required this.date,
    required this.time,
    this.serviceType = 'Default',
    this.quantity = 1,
  });

  // Convert to JSON map for saving
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceId': serviceId,
      'title': title,
      'price': price,
      'imageUrl': imageUrl,
      'providerId': providerId,
      'date': date.toIso8601String(),
      'time_hour': time.hour,
      'time_minute': time.minute,
      'serviceType': serviceType,
      'quantity': quantity,
    };
  }

  // Create from JSON map for loading
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      serviceId: json['serviceId'],
      title: json['title'],
      price: json['price'],
      imageUrl: json['imageUrl'],
      providerId: json['providerId'],
      date: DateTime.parse(json['date']),
      time: TimeOfDay(hour: json['time_hour'], minute: json['time_minute']),
      serviceType: json['serviceType'],
      quantity: json['quantity'],
    );
  }
}

// 2. CART PROVIDER (With Auto-Save Logic)
class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];

  List<CartItem> get items => _items;

  CartProvider() {
    _loadCartFromStorage(); // Load data when app starts
  }

  // --- PERSISTENCE LOGIC ---

  Future<void> _saveCartToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    // Convert list of objects to list of strings
    final String encodedData = jsonEncode(
      _items.map((item) => item.toJson()).toList(),
    );
    await prefs.setString('user_cart', encodedData);
  }

  Future<void> _loadCartFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('user_cart')) {
      final String? encodedData = prefs.getString('user_cart');
      if (encodedData != null) {
        final List<dynamic> decodedList = jsonDecode(encodedData);
        _items = decodedList.map((item) => CartItem.fromJson(item)).toList();
        notifyListeners();
      }
    }
  }

  // --- CART ACTIONS ---

  void addToCart(CartItem item) {
    // Check if exact item exists to just increase quantity instead of duplicating
    int index = _items.indexWhere(
      (i) => i.serviceId == item.serviceId && i.date == item.date,
    );

    if (index != -1) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }

    _saveCartToStorage(); // Save changes
    notifyListeners();
  }

  void removeFromCart(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveCartToStorage(); // Save changes
    notifyListeners();
  }

  void increaseQuantity(String itemId) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _items[index].quantity++;
      _saveCartToStorage();
      notifyListeners();
    }
  }

  void decreaseQuantity(String itemId) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1 && _items[index].quantity > 1) {
      _items[index].quantity--;
      _saveCartToStorage();
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _saveCartToStorage();
    notifyListeners();
  }
}
