import 'package:flutter/material.dart';
import 'dart:async';

class QueueCompletePage extends StatefulWidget {
  const QueueCompletePage({super.key});

  @override
  State<QueueCompletePage> createState() => _QueueCompletePageState();
}

class _QueueCompletePageState extends State<QueueCompletePage> {
  @override
  void initState() {
    super.initState();

    // ⏳ Auto redirect lepas 3 saat ke Home
    Timer(const Duration(seconds: 3), () {
      Navigator.pop(context); // back ke page sebelum ni (contohnya MyQueuePage)
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme; //
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'MediQTrack',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                height: 130,
                width: 130,
                decoration: BoxDecoration(
                  color: Colors.white, // latar belakang putih
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: scheme.primary,
                    width: 5, // tebal biru luar
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: scheme.primary, // 💙 biru MediQTrack
                  size: 80,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Queue Complete',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'You’ll be redirected shortly...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
