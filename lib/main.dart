import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager (Enhanced)',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.indigo,
          secondary: Colors.indigoAccent,
          background: Colors.black,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          return const TaskScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } catch (e) {
      showError('Login failed: $e');
    }
  }

  Future<void> register() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } catch (e) {
      showError('Registration failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login/Register')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: login, child: const Text('Login')),
                ElevatedButton(
                    onPressed: register, child: const Text('Register')),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final taskController = TextEditingController();
  String priority = 'Medium';
  DateTime? dueDate;
  String sortOption = 'Due Date';
  String filterPriority = 'All';
  bool showCompleted = true;

  final user = FirebaseAuth.instance.currentUser!;
  late final CollectionReference taskRef;

  @override
  void initState() {
    super.initState();
    taskRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks');
  }

  Future<void> addTask() async {
    if (taskController.text.trim().isEmpty) return;
    await taskRef.add({
      'title': taskController.text.trim(),
      'priority': priority,
      'completed': false,
      'dueDate': dueDate ?? Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    taskController.clear();
    setState(() => dueDate = null);
  }

  void logout() => FirebaseAuth.instance.signOut();

  Query getSortedFilteredQuery() {
    Query query = taskRef;

    if (filterPriority != 'All') {
      query = query.where('priority', isEqualTo: filterPriority);
    }
    if (!showCompleted) {
      query = query.where('completed', isEqualTo: false);
    }
    if (sortOption == 'Priority') {
      query = query.orderBy('priority');
    } else if (sortOption == 'Completion') {
      query = query.orderBy('completed');
    } else {
      query = query.orderBy('dueDate');
    }

    return query;
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks for ${user.email}'),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: taskController,
                        decoration:
                            const InputDecoration(labelText: 'New Task'),
                      ),
                    ),
                    DropdownButton<String>(
                      value: priority,
                      items: ['High', 'Medium', 'Low']
                          .map((level) => DropdownMenuItem(
                              value: level, child: Text(level)))
                          .toList(),
                      onChanged: (val) => setState(() => priority = val!),
                    ),
                    IconButton(onPressed: addTask, icon: const Icon(Icons.add)),
                  ],
                ),
                Row(
                  children: [
                    const Text("Sort by: "),
                    DropdownButton<String>(
                      value: sortOption,
                      items: ['Due Date', 'Priority', 'Completion']
                          .map((option) => DropdownMenuItem(
                              value: option, child: Text(option)))
                          .toList(),
                      onChanged: (val) => setState(() => sortOption = val!),
                    ),
                    const SizedBox(width: 20),
                    const Text("Filter: "),
                    DropdownButton<String>(
                      value: filterPriority,
                      items: ['All', 'High', 'Medium', 'Low']
                          .map((option) => DropdownMenuItem(
                              value: option, child: Text(option)))
                          .toList(),
                      onChanged: (val) => setState(() => filterPriority = val!),
                    ),
                    const SizedBox(width: 10),
                    Checkbox(
                      value: showCompleted,
                      onChanged: (val) => setState(() => showCompleted = val!),
                    ),
                    const Text("Show completed")
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getSortedFilteredQuery().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: Checkbox(
                        value: data['completed'] ?? false,
                        onChanged: (_) => doc.reference.update({
                          'completed': !(data['completed'] ?? false),
                        }),
                      ),
                      title: Text(data['title']),
                      subtitle: Text(
                          'Priority: ${data['priority']} | Due: ${(data['dueDate'] as Timestamp).toDate()}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: getPriorityColor(data['priority']),
                              shape: BoxShape.circle,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => doc.reference.delete(),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
