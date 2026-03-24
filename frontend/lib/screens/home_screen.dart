import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
const HomeScreen({super.key});

@override
Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.white,
    body: const Center(
        child: Text(
        'Welcome to BIN!',
        style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: Color(0xFFCCCCCC),
            letterSpacing: 4,
        ),
        ),
    ),
    );
}
}
