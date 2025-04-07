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
          surface: Color(0xFF121212),
          background: Colors.black,
        ),
        cardColor: const Color(0xFF1E1E1E),
        dialogBackgroundColor: const Color(0xFF252525),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
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
  bool isLoading = false;

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      showError('Email and password cannot be empty');
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } catch (e) {
      showError('Login failed: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> register() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      showError('Email and password cannot be empty');
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } catch (e) {
      showError('Registration failed: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login/Register',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                    ),
                    child: const Text('Login'),
                  ),
                  ElevatedButton(
                    onPressed: register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                    ),
                    child: const Text('Register'),
                  ),
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
        return Colors.redAccent;
      case 'Medium':
        return Colors.orangeAccent;
      case 'Low':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tasks for ${user.email}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: taskController,
                        decoration: const InputDecoration(
                          labelText: 'New Task',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: priority,
                        dropdownColor: Colors.grey[850],
                        underline: Container(),
                        items: ['High', 'Medium', 'Low']
                            .map((level) => DropdownMenuItem(
                                value: level,
                                child: Text(level,
                                    style: TextStyle(
                                        color: getPriorityColor(level)))))
                            .toList(),
                        onChanged: (val) => setState(() => priority = val!),
                      ),
                    ),
                    IconButton(
                      onPressed: addTask,
                      icon: const Icon(Icons.add_circle,
                          color: Colors.indigoAccent, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text("Sort by: ",
                          style: TextStyle(color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: sortOption,
                          dropdownColor: Colors.grey[850],
                          underline: Container(),
                          items: ['Due Date', 'Priority', 'Completion']
                              .map((option) => DropdownMenuItem(
                                  value: option, child: Text(option)))
                              .toList(),
                          onChanged: (val) => setState(() => sortOption = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text("Filter: ",
                          style: TextStyle(color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: filterPriority,
                          dropdownColor: Colors.grey[850],
                          underline: Container(),
                          items: ['All', 'High', 'Medium', 'Low']
                              .map((option) => DropdownMenuItem(
                                  value: option, child: Text(option)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => filterPriority = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: showCompleted,
                              onChanged: (val) =>
                                  setState(() => showCompleted = val!),
                              checkColor: Colors.black,
                              fillColor:
                                  MaterialStateProperty.resolveWith<Color>(
                                      (states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.indigoAccent;
                                }
                                return Colors.grey;
                              }),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text("Show completed",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getSortedFilteredQuery().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No tasks found',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isCompleted = data['completed'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      color: Colors.grey[900],
                      elevation: 2,
                      child: ListTile(
                        leading: Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: isCompleted,
                            onChanged: (_) => doc.reference.update({
                              'completed': !isCompleted,
                            }),
                            checkColor: Colors.black,
                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                (states) {
                              if (states.contains(MaterialState.selected)) {
                                return getPriorityColor(data['priority']);
                              }
                              return Colors.grey;
                            }),
                          ),
                        ),
                        title: Text(
                          data['title'],
                          style: TextStyle(
                            decoration:
                                isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? Colors.grey : Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Priority: ${data['priority']} | Due: ${(data['dueDate'] as Timestamp).toDate().toString().substring(0, 16)}',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: getPriorityColor(data['priority']),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => doc.reference.delete(),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
