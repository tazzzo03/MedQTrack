import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class JoinQueuePage extends StatefulWidget {
  final int patientId; // ambil dari Firebase/Auth bila login
  const JoinQueuePage({super.key, required this.patientId});

  @override
  State<JoinQueuePage> createState() => _JoinQueuePageState();
}

class _JoinQueuePageState extends State<JoinQueuePage> {
  double? _distance;
  bool _joining = false;
  String? _queueNumber;
  final bool _loading = true;
  final bool _inside = false;

  final double _clinicLat = 2.086099;
  final double _clinicLng = 102.599145;
  final double _radius = 150; // meter

  @override
  void initState() {
    super.initState();
  }


  Future<void> joinQueue() async {
    setState(() => _joining = true);

    final url = Uri.parse('http://10.82.150.157:8000/api/join-queue'); // emulator
    // kalau real device → guna IP LAN laptop contoh http://10.82.150.157:8000/api/join-queue

    final response = await http.post(url, body: {
      'patient_id': widget.patientId.toString(),
    });

    final data = json.decode(response.body);

    setState(() => _joining = false);

    if (response.statusCode == 200 && data['success'] == true) {
      setState(() => _queueNumber = data['queue_number']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined queue! Number: ${data['queue_number']}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Failed to join queue')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Join Queue")),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_distance != null)
                    Text(
                      _inside
                          ? "✅ You are within ${_distance!.toStringAsFixed(1)} m of the clinic."
                          : "⚠️ You are ${_distance!.toStringAsFixed(1)} m away (outside 150 m radius).",
                      style: TextStyle(
                        color: _inside ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                  _joining
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _inside ? joinQueue : null,
                          child: const Text("Join Queue"),
                        ),
                  if (_queueNumber != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Your Queue Number: $_queueNumber',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
