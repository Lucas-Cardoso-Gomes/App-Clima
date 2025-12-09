import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "",
        authDomain: "",
        projectId: "",
        storageBucket: "",
        messagingSenderId: "",
        appId: "",
      ),
    );
  } catch (e) {
    print("Erro ao iniciar Firebase: $e");
  }

  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Clima',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const TelaPrincipal();
          }
          return const TelaLogin();
        },
      ),
    );
  }
}

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});
  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _logado = true;

  Future<void> _autenticar() async {
    try {
      if (_logado) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim(),
        );
      } else {
        UserCredential userCred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _senhaController.text.trim(),
            );
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userCred.user!.uid)
            .set({
              'email': _emailController.text.trim(),
              'cep': '',
            });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_logado ? 'Login' : 'Criar Conta')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            TextField(
              controller: _senhaController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _autenticar,
              child: Text(_logado ? 'Entrar' : 'Cadastrar'),
            ),
            TextButton(
              onPressed: () => setState(() => _logado = !_logado),
              child: Text(
                _logado
                    ? 'Não tem conta? Crie uma aqui'
                    : 'Já tem conta? Faça login',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});
  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  String _cep = '';
  String _cidade = '';
  String _temperatura = '';
  bool _carregando = false;

  final String _apiKey = '9cfa383d4af7607e2a705dbfcaadbf76';

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (doc.exists && doc['cep'] != '') {
        setState(() {
          _cep = doc['cep'];
        });
        _buscarClima(_cep);
      }
    }
  }

  Future<void> _buscarClima(String cep) async {
    setState(() => _carregando = true);
    try {
      final viaCepUrl = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final viaCepRes = await http.get(viaCepUrl);
      final viaCepData = json.decode(viaCepRes.body);

      if (viaCepData['erro'] == true) {
        throw Exception("CEP não encontrado");
      }

      String cidade = viaCepData['localidade'];

      final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$cidade,br&appid=$_apiKey&units=metric&lang=pt_br',
      );
      final weatherRes = await http.get(weatherUrl);
      final weatherData = json.decode(weatherRes.body);

      setState(() {
        _cidade = cidade;
        _temperatura = "${weatherData['main']['temp']}°C";
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao buscar clima: $e")));
    }
  }

  Future<void> _atualizarCep() async {
    TextEditingController cepController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Digite seu CEP"),
        content: TextField(
          controller: cepController,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(user.uid)
                    .update({'cep': cepController.text});
                Navigator.pop(context);
                setState(() {
                  _cep = cepController.text;
                });
                _buscarClima(_cep);
              }
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Previsão do Tempo")),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Usuário"),
              accountEmail: Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_location),
              title: const Text("Alterar meu CEP"),
              onTap: () {
                Navigator.pop(context);
                _atualizarCep();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Gerenciar Usuários"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const TelaAdmin()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text("Sair"),
              onTap: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
      ),
      body: Center(
        child: _carregando
            ? const CircularProgressIndicator()
            : _cep.isEmpty
            ? ElevatedButton(
                onPressed: _atualizarCep,
                child: const Text("Cadastrar CEP"),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _cidade,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _temperatura,
                    style: const TextStyle(fontSize: 64, color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  Text("CEP: $_cep"),
                ],
              ),
      ),
    );
  }
}

class TelaAdmin extends StatelessWidget {
  const TelaAdmin({super.key});

  void _editarCep(BuildContext context, String userId, String cepAtual) {
    TextEditingController cepController = TextEditingController(text: cepAtual);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar CEP"),
        content: TextField(
          controller: cepController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Novo CEP"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(userId)
                  .update({'cep': cepController.text.trim()});

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("CEP atualizado com sucesso.")),
              );
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestão de Usuários")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;
          String meuId = FirebaseAuth.instance.currentUser!.uid;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var dados = docs[index].data() as Map<String, dynamic>;
              String idUsuario = docs[index].id;

              return ListTile(
                title: Text(dados['email'] ?? 'Sem email'),
                subtitle: Text("CEP: ${dados['cep']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editarCep(
                        context,
                        idUsuario,
                        dados['cep'] ?? '',
                      ),
                    ),
                    if (idUsuario != meuId)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          bool confirmar = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Confirmar exclusão"),
                              content: const Text(
                                "Tem certeza que deseja excluir este usuário?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancelar"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Excluir"),
                                ),
                              ],
                            ),
                          ) ?? false;

                          if (confirmar) {
                            try {
                              // Tenta chamar a Cloud Function para exclusão completa
                              await FirebaseFunctions.instance
                                  .httpsCallable('deleteUser')
                                  .call({'uid': idUsuario});

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Usuário excluído com sucesso!"),
                                ),
                              );
                            } catch (e) {
                              debugPrint("Erro na Cloud Function deleteUser: $e");
                              // Fallback: Se a função falhar (ex: não implantada), tenta deletar só do Firestore
                              // e avisa o usuário.
                              try {
                                await FirebaseFirestore.instance
                                    .collection('usuarios')
                                    .doc(idUsuario)
                                    .delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Aviso: Usuário removido via Firestore. A conta de Auth deve ser removida automaticamente (verifique o Trigger).",
                                    ),
                                  ),
                                );
                              } catch (firestoreError) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Erro ao excluir usuário: $firestoreError",
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
