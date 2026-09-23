import 'package:flutter/material.dart';

/// Form validation utility functions
class Validators {
  /// Validate that a field is not empty
  static String? required(String? value, [String fieldName = 'Field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate amount (must be positive number)
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid amount';
    }
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  /// Validate note length
  static String? note(String? value) {
    if (value != null && value.length > 250) {
      return 'Note must not exceed 250 characters';
    }
    return null;
  }

  /// Validate category name
  static String? categoryName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Category name is required';
    }
    if (value.length > 50) {
      return 'Category name must not exceed 50 characters';
    }
    return null;
  }
}
