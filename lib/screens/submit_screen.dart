import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});

  @override
  _SubmitScreenState createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  String? _selectedLocation;
  String? _selectedCategory;

  final List<String> _locations = [
    'Comunidad Kapawi',
    'Comunidad Kasutkao',
    'Comunidad Suwa',
    'Kapawi Ecolodge',
    'Colegio Tuna'
  ];
  final List<String> _categories = [
    'Frases y palabras básicas',
    'Ecoturismo',
    'Fauna silvestre',
    'Estilo de vida',
    'Otro'
  ];

  final TextEditingController _achuarController = TextEditingController();
  final TextEditingController _spanishController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  List<Map<String, dynamic>> _pendingSubmissions = [];
  bool _isSyncing = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadPendingSubmissions();
    _initConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _loadPendingSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pendingSubmissions') ?? [];
    if (mounted) {
      setState(() {
        _pendingSubmissions = pending.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _savePendingSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _pendingSubmissions.map((s) => jsonEncode(s)).toList();
    await prefs.setStringList('pendingSubmissions', pending);
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
      _syncPendingSubmissions();
    }
  }

  void _syncPendingSubmissions() async {
  if (_isSyncing || _pendingSubmissions.isEmpty) {
    return;
  }
  if (mounted) {
    setState(() {
      _isSyncing = true;
    });
  }

  List<Map<String, dynamic>> submissionsToSync = List.from(_pendingSubmissions);
  _pendingSubmissions.clear();
  await _savePendingSubmissions();


  for (var submission in submissionsToSync) {
    try {
      final Map<String, dynamic> submissionWithTimestamp = Map<String, dynamic>.from(submission);
      submissionWithTimestamp['timestamp'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('achuar_submission').add(submissionWithTimestamp);
    } catch (e) {
      debugPrint("Error syncing submission: $e");
      if(mounted){
        setState(() {
          _pendingSubmissions.add(submission);
        });
      }
    }
  }

  if (mounted) {
    setState(() {
      _isSyncing = false;
    });
  }
  await _savePendingSubmissions();
}

  void _submit() async {
    if (_achuarController.text.isNotEmpty && _spanishController.text.isNotEmpty) {
      final submission = {
        'achuar': _achuarController.text,
        'spanish': _spanishController.text,
        'notes': _notesController.text,
        'location': _selectedLocation,
        'category': _selectedCategory,
      };

      if (_connectionStatus.contains(ConnectivityResult.none)) {
        if (mounted) {
          setState(() {
            _pendingSubmissions.add(submission);
          });
        }
        await _savePendingSubmissions();
        _clearForm();
        _showConfirmationDialog(isOffline: true);
      } else {
        try {
          final submissionWithTimestamp = Map<String, dynamic>.from(submission);
          submissionWithTimestamp['timestamp'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance.collection('achuar_submission').add(submissionWithTimestamp);
          _clearForm();
          _showConfirmationDialog();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al enviar la contribución: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete los campos obligatorios')),
      );
    }
  }

  void _clearForm() {
    _achuarController.clear();
    _spanishController.clear();
    _notesController.clear();
  }

  void _showConfirmationDialog({bool isOffline = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isOffline ? 'Guardado localmente' : 'Éxito'),
          content: Text(isOffline
              ? 'Tu contribución ha sido guardada y se subirá automáticamente cuando te conectes a internet.'
              : 'Tu contribución ha sido enviada con éxito.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traductor Achuar-Español'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField('Frase en Achuar', _achuarController),
              const SizedBox(height: 20),
              _buildTextField('Frase en Español', _spanishController),
              const SizedBox(height: 20),
              _buildDropdown('Seleccione una ubicación', _selectedLocation, _locations, (newValue) {
                if (mounted) {
                  setState(() {
                    _selectedLocation = newValue;
                  });
                }
              }),
              const SizedBox(height: 20),
              _buildDropdown('Seleccione una categoría', _selectedCategory, _categories, (newValue) {
                if (mounted) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                }
              }),
              const SizedBox(height: 20),
              _buildTextField('Notas (Opcional)', _notesController),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 30),
              _buildStatusSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    bool isOffline = _connectionStatus.contains(ConnectivityResult.none);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(isOffline ? Icons.wifi_off : Icons.wifi, color: isOffline ? Colors.red : Colors.green),
        const SizedBox(width: 8),
        Text(isOffline ? 'Desconectado' : 'En línea',
            style: TextStyle(color: isOffline ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDropdown(String hint, String? value, List<String> items, ValueChanged<String?> onChanged) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey)),
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
          dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey),
          filled: true,
          fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[700]!, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
        ),
        child: const Text(
          'Enviar',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
