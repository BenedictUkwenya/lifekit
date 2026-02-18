import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. CART ITEM MODEL (Updated with 'comments')
class CartItem {
  final String id;
  final String serviceId;
  final String title;
  final double price;
  final String imageUrl;
  final String providerId;
  DateTime date;
  TimeOfDay time;
  String serviceType; // <--- Add this
  final String? location; // <--- Add this
  final String? comments; // <--- 1. Added Field
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
    required this.serviceType, // <--- Add this
    this.location, // <--- Add this
    this.comments = '', // <--- 2. Added to Constructor (Default empty)
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
      'comments': comments, // <--- 3. Added to JSON export
      'quantity': quantity,
    };
  }

  // Create from JSON map for loading
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      serviceId: json['serviceId'],
      title: json['title'],
      price: (json['price'] as num).toDouble(), // Safe cast for double
      imageUrl: json['imageUrl'],
      providerId: json['providerId'],
      date: DateTime.parse(json['date']),
      time: TimeOfDay(hour: json['time_hour'], minute: json['time_minute']),
      serviceType: json['serviceType'] ?? 'Default',
      comments:
          json['comments'] ??
          '', // <--- 4. Added to JSON import (with safety check)
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
        try {
          final List<dynamic> decodedList = jsonDecode(encodedData);
          _items = decodedList.map((item) => CartItem.fromJson(item)).toList();
          notifyListeners();
        } catch (e) {
          print("Error loading cart: $e");
          // Optional: clear corrupted data
          // prefs.remove('user_cart');
        }
      }
    }
  }

  // --- CART ACTIONS ---

  void addToCart(CartItem item) {
    // Check if exact item exists (Same Service + Same Date + Same Options)
    // We strictly compare comments too, because "No Onions" vs "Extra Onions" are different items.
    int index = _items.indexWhere(
      (i) =>
          i.serviceId == item.serviceId &&
          i.date == item.date &&
          i.comments == item.comments,
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
