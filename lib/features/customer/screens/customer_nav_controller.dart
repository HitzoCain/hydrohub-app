import 'package:flutter/foundation.dart';

class CustomerNavController extends ChangeNotifier {
  CustomerNavController._();

  static final CustomerNavController instance = CustomerNavController._();

  int _index = 0;

  int get index => _index;

  void goTo(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }
}
