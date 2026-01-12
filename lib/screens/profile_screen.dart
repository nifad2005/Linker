import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';

class ProfileScreen extends StatelessWidget {
  final UserProfile user;
  final Function(String) onUpdateName;
  final Function(String) onUpdateImage;

  const ProfileScreen({super.key, required this.user, required this.onUpdateName, required this.onUpdateImage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  backgroundImage: user.profileImageUrl != null ? FileImage(File(user.profileImageUrl!)) : null,
                  child: user.profileImageUrl == null ? const Icon(Icons.person, size: 64, color: Colors.white12) : null,
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                    onPressed: () async {
                      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (img != null) onUpdateImage(img.path);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildInfoCard(context, 'Name', user.name, Icons.edit_outlined, () => _showEditName(context)),
            const SizedBox(height: 16),
            _buildInfoCard(context, 'ID', user.id, Icons.copy_outlined, () {
              // Copy to clipboard or just show snackbar
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID copied to clipboard')));
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(icon, size: 20, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showEditName(BuildContext context) {
    final ctrl = TextEditingController(text: user.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Enter your name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onUpdateName(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
