import 'package:flutter/material.dart';
import '../models.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile user;
  final Function(String) onUpdateName;

  const ProfileScreen({
    super.key, 
    required this.user, 
    required this.onUpdateName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withAlpha(13),
              child: Text(
                widget.user.name.isNotEmpty ? widget.user.name.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              cursorColor: Colors.greenAccent,
              decoration: InputDecoration(
                labelText: 'Global Name',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Enter your name',
                prefixIcon: const Icon(Icons.person_outline, color: Colors.greenAccent),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.greenAccent),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: Colors.white.withAlpha(5),
              ),
              onChanged: widget.onUpdateName,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fingerprint, color: Colors.greenAccent),
                      const SizedBox(width: 12),
                      const Text('Global ID', style: TextStyle(color: Colors.white38)),
                      const Spacer(),
                      Text(widget.user.id, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.greenAccent)),
                    ],
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  const Row(
                    children: [
                      Icon(Icons.security, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your ID is public. Share it with friends to connect instantly.',
                          style: TextStyle(fontSize: 12, color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
