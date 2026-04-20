// lib/screens/debug_destinations_screen.dart
// USE THIS TO DEBUG WHY DATA ISN'T SHOWING

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/destination_model_fixed.dart';

class DebugDestinationsScreen extends StatefulWidget {
  const DebugDestinationsScreen({super.key});

  @override
  State<DebugDestinationsScreen> createState() =>
      _DebugDestinationsScreenState();
}

class _DebugDestinationsScreenState extends State<DebugDestinationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  List<Map<String, dynamic>> _rawData = [];
  List<Destination> _parsedData = [];
  String _error = '';
  bool _isLoading = true;
  int _totalDocs = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Step 1: Get raw Firestore data
      print('📡 Fetching raw Firestore data...');
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('destinations')
          .get();

      _totalDocs = snapshot.docs.length;
      print('📊 Found $_totalDocs documents in Firestore');

      // Store raw data for debugging
      _rawData = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['_docId'] = doc.id; // Add doc ID for reference
        return data;
      }).toList();

      // Step 2: Try parsing with Destination model
      print('🔄 Parsing with Destination model...');
      _parsedData = [];
      for (var doc in snapshot.docs) {
        try {
          Destination dest = Destination.fromFirestore(doc);
          _parsedData.add(dest);
          print('✅ Parsed: ${dest.name}');
        } catch (e) {
          print('❌ Failed to parse doc ${doc.id}: $e');
        }
      }

      print('✅ Successfully parsed ${_parsedData.length} destinations');
    } catch (e) {
      _error = e.toString();
      print('❌ Error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Destinations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Card(
                    color: _error.isEmpty ? Colors.green[50] : Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _error.isEmpty
                                  ? Colors.green[800]
                                  : Colors.red[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Firestore Documents', '$_totalDocs'),
                          _buildInfoRow('Raw Data Items', '${_rawData.length}'),
                          _buildInfoRow(
                            'Parsed Destinations',
                            '${_parsedData.length}',
                          ),
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Error: $_error',
                              style: TextStyle(color: Colors.red[800]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Problem Diagnosis
                  if (_totalDocs == 0) ...[
                    _buildProblemCard(
                      '🚨 NO DATA IN FIRESTORE',
                      'Your Firestore "destinations" collection is empty!',
                      'Solution: Run the upload function first.',
                      Colors.red,
                    ),
                  ] else if (_parsedData.isEmpty && _rawData.isNotEmpty) ...[
                    _buildProblemCard(
                      '⚠️ PARSING ERROR',
                      'Data exists but cannot be parsed into Destination model.',
                      'Check the data structure below.',
                      Colors.orange,
                    ),
                  ] else if (_parsedData.length < _rawData.length) ...[
                    _buildProblemCard(
                      '⚠️ PARTIAL PARSING',
                      '${_rawData.length - _parsedData.length} documents failed to parse.',
                      'Some data structure issues exist.',
                      Colors.yellow[700]!,
                    ),
                  ] else ...[
                    _buildProblemCard(
                      '✅ ALL GOOD!',
                      'All ${_parsedData.length} destinations loaded successfully.',
                      'Data is working correctly.',
                      Colors.green,
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Raw Data Sample
                  const Text(
                    'Raw Firestore Data (First 3):',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._rawData
                      .take(3)
                      .map(
                        (data) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? 'NO NAME',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Doc ID: ${data['_docId']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const Divider(),
                                ...data.entries
                                    .where((e) => e.key != '_docId')
                                    .take(10)
                                    .map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                '${e.key}:',
                                                style: TextStyle(
                                                  color: Colors.blue[700],
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                '${e.value.runtimeType}: ${_truncate(e.value.toString(), 50)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),

                  const SizedBox(height: 20),

                  // Parsed Destinations
                  const Text(
                    'Parsed Destinations (First 5):',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._parsedData
                      .take(5)
                      .map(
                        (dest) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                dest.name.isNotEmpty ? dest.name[0] : '?',
                              ),
                            ),
                            title: Text(dest.name),
                            subtitle: Text(
                              '${dest.state} • ${dest.places.length} places • ⭐ ${dest.rating}',
                            ),
                            trailing: Icon(
                              dest.places.isNotEmpty
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: dest.places.isNotEmpty
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ),

                  const SizedBox(height: 40),

                  // Quick Actions
                  const Text(
                    'Quick Actions:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Test getting by region
                          var himachal = await _firebaseService
                              .getDestinationsByState('Himachal Pradesh');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Himachal: ${himachal.length} destinations',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Test Himachal Query'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          var all = await _firebaseService.getAllDestinations();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('All destinations: ${all.length}'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.list),
                        label: const Text('Test Get All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProblemCard(
    String title,
    String description,
    String solution,
    Color color,
  ) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 4),
            Text(
              solution,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
