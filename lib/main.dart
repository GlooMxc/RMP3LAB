import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // Импортируем intl для форматирования дат

void main() => runApp(TodoApp());

class TodoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TodoListScreen(),
    );
  }
}

class Todo {
  String title;
  String description;
  bool isCompleted;
  String date;

  Todo({required this.title, required this.description, this.isCompleted = false, required this.date});

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'isCompleted': isCompleted,
    'date': date,
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    title: json['title'],
    description: json['description'],
    isCompleted: json['isCompleted'],
    date: json['date'],
  );
}

class TodoListScreen extends StatefulWidget {
  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<Todo> todos = [];
  String filter = 'current';

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? todosString = prefs.getString('todos');
    if (todosString != null) {
      List<dynamic> todosJson = jsonDecode(todosString);
      setState(() {
        todos = todosJson.map((e) => Todo.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveTodos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String todosString = jsonEncode(todos);
    await prefs.setString('todos', todosString);
  }

  void _addOrEditTask([Todo? todo]) async {
    if (todo != null && todo.isCompleted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TodoEditScreen(todo: todo),
      ),
    );

    if (result != null) {
      setState(() {
        if (todo != null) {
          final index = todos.indexOf(todo);
          todos[index] = result;
        } else {
          todos.add(result);
        }
      });
      _saveTodos();
    }
  }

  void _toggleCompletion(Todo todo) {
    setState(() {
      todo.isCompleted = !todo.isCompleted;
    });
    _saveTodos();
  }

  void _deleteTask(Todo todo) {
    setState(() {
      todos.remove(todo);
    });
    _saveTodos();
  }

  @override
  Widget build(BuildContext context) {
    List<Todo> filteredTodos = filter == 'current'
        ? todos.where((todo) => !todo.isCompleted).toList()
        : todos.where((todo) => todo.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('ToDo'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                filter = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'current',
                child: Text('Текущие задачи'),
              ),
              PopupMenuItem(
                value: 'completed',
                child: Text('Выполнено'),
              ),
            ],
          )
        ],
      ),
      body: filteredTodos.isEmpty
          ? Center(
        child: Text('Задач нет'),
      )
          : ListView.builder(
        itemCount: filteredTodos.length,
        itemBuilder: (context, index) {
          final todo = filteredTodos[index];
          return ListTile(
            title: Text(todo.title,
                style: TextStyle()),
            subtitle: Text('${todo.description}\nДата: ${todo.date}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!todo.isCompleted)
                  IconButton(
                    icon: Icon(Icons.check_circle),
                    onPressed: () => _toggleCompletion(todo),
                  ),
                if (!todo.isCompleted)
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _addOrEditTask(todo),
                  ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deleteTask(todo),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _addOrEditTask(),
      ),
    );
  }
}

class TodoEditScreen extends StatefulWidget {
  final Todo? todo;

  TodoEditScreen({this.todo});

  @override
  _TodoEditScreenState createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  DateTime? selectedDate;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.todo?.title ?? '');
    descriptionController = TextEditingController(text: widget.todo?.description ?? '');
    selectedDate = widget.todo != null ? DateTime.tryParse(widget.todo!.date) : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.todo == null ? 'Добавить задачу' : 'Изменить'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Название',
                errorText: errorMessage.isEmpty ? null : errorMessage,
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: 'Описание'),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Text('Дата: ${selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : "Не выбрано"}'),
                Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Text('Выбрать дату'),
                ),
              ],
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  setState(() {
                    errorMessage = 'Введите название задачи';
                  });
                  return;
                }

                if (selectedDate == null) return;

                final newTodo = Todo(
                  title: titleController.text,
                  description: descriptionController.text,
                  isCompleted: widget.todo?.isCompleted ?? false,
                  date: DateFormat('yyyy-MM-dd').format(selectedDate!),
                );
                Navigator.pop(context, newTodo);
              },
              child: Text('Сохранить задачу'),
            ),
          ],
        ),
      ),
    );
  }
}
