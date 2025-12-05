import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaFinanceiro extends StatefulWidget {
  const TelaFinanceiro({super.key});

  @override
  State<TelaFinanceiro> createState() => _TelaFinanceiroState();
}

class _TelaFinanceiroState extends State<TelaFinanceiro> {
  final List<String> _mesesKey = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez'
  ];
  final List<String> _mesesLabel = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro'
  ];

  User? get _user => FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot> _getStream(String tipo) {
    if (_user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_user!.uid)
        .collection('financeiro_items')
        .where('tipo', isEqualTo: tipo)
        .snapshots();
  }

  Future<void> _updateValue(
      String docId, String monthKey, double value) async {
    if (_user == null) return;
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_user!.uid)
        .collection('financeiro_items')
        .doc(docId)
        .update({'valores.$monthKey': value});
  }

  Future<void> _addItem(String tipo, String nome) async {
    if (_user == null) return;
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_user!.uid)
        .collection('financeiro_items')
        .add({
      'tipo': tipo,
      'nome': nome,
      'valores': {},
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteItem(String docId) async {
    if (_user == null) return;
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_user!.uid)
        .collection('financeiro_items')
        .doc(docId)
        .delete();
  }

  void _showEditDialog(String docId, String monthKey, double currentValue) {
    TextEditingController controller =
        TextEditingController(text: currentValue.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Valor"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: "R\$ "),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              double? newValue =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              if (newValue != null) {
                _updateValue(docId, monthKey, newValue);
              }
              Navigator.pop(context);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(String tipo) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            "Adicionar ${tipo == 'fixo' ? 'Gasto Fixo' : tipo == 'cartao' ? 'Gasto Cartão' : 'Salário'}"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Nome do Item"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addItem(tipo, controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text("Adicionar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Planilha Financeira")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSection("Gastos Mensais (Fixos)", "fixo", Colors.green[100]!),
            const SizedBox(height: 20),
            _buildSection("Gasto Mensal no Cartão", "cartao", Colors.green[100]!),
            const SizedBox(height: 20),
            _buildSection("Salários", "salario", Colors.white),
            const SizedBox(height: 20),
            _buildSummary(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String tipo, Color headerColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getStream(tipo),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;

        // Sort items by creation time or name if possible, for now just docs order
        // We can sort in memory
        // docs.sort((a, b) => (a['nome'] as String).compareTo(b['nome'] as String));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: () => _showAddDialog(tipo),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(headerColor),
                columns: [
                  const DataColumn(label: Text("Item")),
                  ..._mesesLabel.map((m) => DataColumn(label: Text(m))),
                  const DataColumn(label: Text("Total")),
                  const DataColumn(label: Text("Ações")),
                ],
                rows: [
                  ...docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    Map<String, dynamic> valores =
                        data['valores'] as Map<String, dynamic>? ?? {};
                    double totalRow = 0;
                    _mesesKey.forEach((k) {
                      totalRow += (valores[k] ?? 0).toDouble();
                    });

                    return DataRow(cells: [
                      DataCell(Text(data['nome'] ?? '')),
                      ..._mesesKey.map((key) {
                        double val = (valores[key] ?? 0).toDouble();
                        return DataCell(
                          Text(
                              val == 0 ? '' : "R\$ ${val.toStringAsFixed(2)}"),
                          onTap: () => _showEditDialog(doc.id, key, val),
                        );
                      }).toList(),
                      DataCell(Text(
                          "R\$ ${totalRow.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(
                        const Icon(Icons.delete, color: Colors.red, size: 20),
                        onTap: () => _deleteItem(doc.id),
                      ),
                    ]);
                  }).toList(),
                  // Totals Row
                  DataRow(
                    color: MaterialStateProperty.all(Colors.grey[200]),
                    cells: [
                      const DataCell(Text("Total Mensal",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                      ..._mesesKey.map((key) {
                        double totalCol = 0;
                        for (var doc in docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          var vals = data['valores'] as Map<String, dynamic>? ?? {};
                          totalCol += (vals[key] ?? 0).toDouble();
                        }
                        return DataCell(Text(
                            "R\$ ${totalCol.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold)));
                      }).toList(),
                      DataCell(Text(
                        "R\$ ${docs.fold(0.0, (prev, doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          var vals = data['valores'] as Map<String, dynamic>? ?? {};
                          double rowTot = 0;
                          _mesesKey.forEach((k) => rowTot += (vals[k] ?? 0).toDouble());
                          return prev + rowTot;
                        }).toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      const DataCell(SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummary() {
    // This widget needs access to all streams to calculate the balance.
    // Combining streams can be complex.
    // Alternatively, we can just fetch all items at once in the main build or use a StreamBuilder that listens to the whole collection.
    // A query snapshot on the parent collection 'financeiro_items' gives everything.

    return StreamBuilder<QuerySnapshot>(
      stream: _user != null
          ? FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_user!.uid)
              .collection('financeiro_items')
              .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var docs = snapshot.data!.docs;

        var fixos = docs.where((d) => d['tipo'] == 'fixo');
        var cartao = docs.where((d) => d['tipo'] == 'cartao');
        var salarios = docs.where((d) => d['tipo'] == 'salario');

        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.orange[100]),
              columns: [
                const DataColumn(label: Text("Resumo")),
                ..._mesesLabel.map((m) => DataColumn(label: Text(m))),
                const DataColumn(label: Text("Total Anual")),
              ],
              rows: [
                _buildSummaryRow("Total Fixos", fixos, Colors.white),
                _buildSummaryRow("Total Cartão", cartao, Colors.white),
                _buildSummaryRow("Total Despesas", [...fixos, ...cartao], Colors.red[50]!),
                _buildSummaryRow("Total Salários", salarios, Colors.green[50]!),
                _buildBalanceRow(salarios, [...fixos, ...cartao]),
              ],
            ));
      },
    );
  }

  DataRow _buildSummaryRow(
      String label, Iterable<QueryDocumentSnapshot> docs, Color color) {
    double totalAnual = 0;
    List<DataCell> cells = [
      DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
    ];

    for (var key in _mesesKey) {
      double totalMes = 0;
      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;
        var vals = data['valores'] as Map<String, dynamic>? ?? {};
        totalMes += (vals[key] ?? 0).toDouble();
      }
      totalAnual += totalMes;
      cells.add(DataCell(Text("R\$ ${totalMes.toStringAsFixed(2)}")));
    }

    cells.add(DataCell(Text("R\$ ${totalAnual.toStringAsFixed(2)}",
        style: const TextStyle(fontWeight: FontWeight.bold))));

    return DataRow(color: MaterialStateProperty.all(color), cells: cells);
  }

  DataRow _buildBalanceRow(Iterable<QueryDocumentSnapshot> incomeDocs,
      Iterable<QueryDocumentSnapshot> expenseDocs) {
    double totalBalanceAnual = 0;
    List<DataCell> cells = [
      const DataCell(Text("Saldo Final",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
    ];

    for (var key in _mesesKey) {
      double income = 0;
      double expense = 0;

      for (var doc in incomeDocs) {
        var data = doc.data() as Map<String, dynamic>;
        var vals = data['valores'] as Map<String, dynamic>? ?? {};
        income += (vals[key] ?? 0).toDouble();
      }
      for (var doc in expenseDocs) {
        var data = doc.data() as Map<String, dynamic>;
        var vals = data['valores'] as Map<String, dynamic>? ?? {};
        expense += (vals[key] ?? 0).toDouble();
      }

      double balance = income - expense;
      totalBalanceAnual += balance;

      cells.add(DataCell(Text(
        "R\$ ${balance.toStringAsFixed(2)}",
        style: TextStyle(
            color: balance >= 0 ? Colors.blue : Colors.red,
            fontWeight: FontWeight.bold),
      )));
    }

    cells.add(DataCell(Text(
      "R\$ ${totalBalanceAnual.toStringAsFixed(2)}",
      style: TextStyle(
          color: totalBalanceAnual >= 0 ? Colors.blue : Colors.red,
          fontWeight: FontWeight.bold),
    )));

    return DataRow(
        color: MaterialStateProperty.all(Colors.grey[300]), cells: cells);
  }
}
