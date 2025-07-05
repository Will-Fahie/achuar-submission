
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  _RecentScreenState createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  List<Map<String, dynamic>> _pendingEdits = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPendingEdits();
    _initConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _loadPendingEdits() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pendingEdits') ?? [];
    if (mounted) {
      setState(() {
        _pendingEdits = pending.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _savePendingEdits() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _pendingEdits.map((s) => jsonEncode(s)).toList();
    await prefs.setStringList('pendingEdits', pending);
  }

  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await Connectivity().checkConnectivity();
    } catch (e) {
      debugPrint("Couldn't check connectivity status: $e");
      return;
    }
    if (!mounted) {
      return;
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    if (mounted) {
      setState(() {
        _connectionStatus = result;
      });
    }
    if (!_connectionStatus.contains(ConnectivityResult.none)) {
      _syncPendingEdits();
    }
  }

  void _syncPendingEdits() async {
    if (_isSyncing || _pendingEdits.isEmpty) return;
    if (mounted) setState(() => _isSyncing = true);

    List<Map<String, dynamic>> editsToSync = List.from(_pendingEdits);
    _pendingEdits.clear();
    await _savePendingEdits();

    for (var edit in editsToSync) {
      try {
        await FirebaseFirestore.instance
            .collection('achuar_submission')
            .doc(edit['docId'])
            .update(edit['data']);
      } catch (e) {
        debugPrint("Error syncing edit: $e");
        if (mounted) {
          setState(() => _pendingEdits.add(edit));
        }
      }
    }

    if (mounted) setState(() => _isSyncing = false);
    await _savePendingEdits();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contribuciones Recientes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('achuar_submission')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay contribuciones recientes.'));
          }

          final submissions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final doc = submissions[index];
              final submission = doc.data() as Map<String, dynamic>;
              final isPending = _pendingEdits.any((edit) => edit['docId'] == doc.id);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                elevation: 4,
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16), // Adjust padding for button
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Achuar: ${submission['achuar']}',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Español: ${submission['spanish']}',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              submission['location'] ?? 'N/A',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (isPending) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Edición pendiente',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.green),
                        onPressed: () => _showEditDialog(context, doc),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final submission = doc.data() as Map<String, dynamic>;
    final achuarController = TextEditingController(text: submission['achuar']);
    final spanishController = TextEditingController(text: submission['spanish']);
    final notesController = TextEditingController(text: submission['notes']);
    String? selectedLocation = submission['location'];
    String? selectedCategory = submission['category'];

    final List<String> locations = [
      'Comunidad Kapawi', 'Comunidad Kasutkao', 'Comunidad Suwa', 'Kapawi Ecolodge', 'Colegio Tuna'
    ];
    final List<String> categories = [
      'Frases y palabras básicas', 'Ecoturismo', 'Fauna silvestre', 'Estilo de vida', 'Otro'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editar Contribución'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: achuarController, decoration: const InputDecoration(labelText: 'Achuar')),
                    TextField(controller: spanishController, decoration: const InputDecoration(labelText: 'Español')),
                    TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Notas')),
                    DropdownButtonFormField<String>(
                      value: selectedLocation,
                      items: locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (val) => setState(() => selectedLocation = val),
                      decoration: const InputDecoration(labelText: 'Ubicación'),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                      decoration: const InputDecoration(labelText: 'Categoría'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final editedData = {
                  'achuar': achuarController.text,
                  'spanish': spanishController.text,
                  'notes': notesController.text,
                  'location': selectedLocation,
                  'category': selectedCategory,
                };

                if (_connectionStatus.contains(ConnectivityResult.none)) {
                  final edit = {'docId': doc.id, 'data': editedData};
                  if(mounted) {
                    setState(() {
                      _pendingEdits.add(edit);
                    });
                  }
                  _savePendingEdits();
                  Navigator.pop(context);
                } else {
                  try {
                    await FirebaseFirestore.instance
                        .collection('achuar_submission')
                        .doc(doc.id)
                        .update(editedData);
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al guardar la edición: $e')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
