import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

class DatabaseViewerScreen extends ConsumerStatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  ConsumerState<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends ConsumerState<DatabaseViewerScreen> {
  String? _selectedTable;
  List<String> _tables = [];
  List<Map<String, dynamic>> _tableData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    final db = await DatabaseService().database;
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata'");
    
    setState(() {
      _tables = tables.map((t) => t['name'] as String).toList();
      if (_tables.isNotEmpty) {
        _selectedTable = _tables.first;
        _loadTableData(_selectedTable!);
      } else {
        _isLoading = false;
      }
    });
  }

  Future<void> _loadTableData(String tableName) async {
    setState(() => _isLoading = true);
    final db = await DatabaseService().database;
    final data = await db.query(tableName);
    setState(() {
      _tableData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاهده پایگاه داده'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedTable != null) _loadTableData(_selectedTable!);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedTable,
              decoration: InputDecoration(
                labelText: 'انتخاب جدول',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _tables.map((table) {
                return DropdownMenuItem(
                  value: table,
                  child: Text(table),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTable = value);
                  _loadTableData(value);
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tableData.isEmpty
                    ? const Center(child: Text('داده‌ای در این جدول وجود ندارد'))
                    : ListView.builder(
                        itemCount: _tableData.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final row = _tableData[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              title: Text('ID: ${row['id'] ?? index}'),
                              subtitle: Text(
                                row.entries
                                    .where((e) => e.key != 'id')
                                    .take(2)
                                    .map((e) => '${e.key}: ${e.value}')
                                    .join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: row.entries.map((e) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${e.key}: ',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Expanded(
                                              child: Text(
                                                e.value.toString(),
                                                style: const TextStyle(fontFamily: 'monospace'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
