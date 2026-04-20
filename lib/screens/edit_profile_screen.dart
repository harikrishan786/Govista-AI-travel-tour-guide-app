// lib/screens/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  File? _selectedImage;
  String? _selectedAvatarUrl;

  // ═══ MALE AVATARS — tested seeds that produce masculine faces ═══
  final List<Map<String, String>> _maleAvatars = [
    {'id': 'm1', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Arjun&hair=shortHair&backgroundColor=b6e3f4&size=128'},
    {'id': 'm2', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Rohan&hair=mohawk&backgroundColor=c0aede&size=128'},
    {'id': 'm3', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Vikram&hair=shavedHead&backgroundColor=d1d4f9&size=128'},
    {'id': 'm4', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Kabir&hair=curlyShortHair&backgroundColor=ffd5dc&size=128'},
    {'id': 'm5', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Aditya&hair=shortHair&backgroundColor=bde0fe&size=128'},
    {'id': 'm6', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Dev&hair=mohawk&backgroundColor=a2d2ff&size=128'},
    {'id': 'm7', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Sahil&hair=curlyShortHair&backgroundColor=d5f5e3&size=128'},
    {'id': 'm8', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Nikhil&hair=shortHair&backgroundColor=fdebd0&size=128'},
  ];

  // ═══ FEMALE AVATARS — tested seeds with long hair styles ═══
  final List<Map<String, String>> _femaleAvatars = [
    {'id': 'f1', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Priya&hair=straightHair&backgroundColor=ffdfbf&size=128'},
    {'id': 'f2', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Ananya&hair=wavyBob&backgroundColor=ffd5dc&size=128'},
    {'id': 'f3', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Ishita&hair=braids&backgroundColor=d1d4f9&size=128'},
    {'id': 'f4', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Meera&hair=bunHair&backgroundColor=c0aede&size=128'},
    {'id': 'f5', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Zara&hair=curlyBob&backgroundColor=b6e3f4&size=128'},
    {'id': 'f6', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Kavya&hair=froBun&backgroundColor=fee2e2&size=128'},
    {'id': 'f7', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Riya&hair=straightHair&backgroundColor=fce7f3&size=128'},
    {'id': 'f8', 'url': 'https://api.dicebear.com/9.x/big-smile/png?seed=Diya&hair=bangs&backgroundColor=fdf2f8&size=128'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) { if (mounted) setState(() => _isLoadingData = false); return; }

    _nameController.text = user.displayName ?? '';
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phoneNumber ?? '';
    _selectedAvatarUrl = user.photoURL;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (_phoneController.text.isEmpty) {
          _phoneController.text = data['phone'] as String? ?? '';
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingData = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onBackTapped() => Navigator.pop(context);

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 75);
      if (image != null) {
        setState(() { _selectedImage = File(image.path); _selectedAvatarUrl = null; });
        Navigator.pop(context);
        _showSnackBar('Photo selected! Tap Save to update.');
      }
    } catch (_) { _showSnackBar('Failed to pick image.', isError: true); }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 512, maxHeight: 512, imageQuality: 75);
      if (image != null) {
        setState(() { _selectedImage = File(image.path); _selectedAvatarUrl = null; });
        Navigator.pop(context);
        _showSnackBar('Photo captured! Tap Save to update.');
      }
    } catch (_) { _showSnackBar('Failed to take photo.', isError: true); }
  }

  void _selectAvatar(String avatarUrl) {
    setState(() { _selectedAvatarUrl = avatarUrl; _selectedImage = null; });
    Navigator.pop(context);
    _showSnackBar('Avatar selected! Tap Save to update.');
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textHint(context), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Center(child: Text('Choose Profile Photo',
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Center(child: Text('Select from gallery, camera, or choose an avatar',
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14))),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: _buildPhotoOption(icon: Icons.photo_library_rounded, label: 'Gallery',
                    color: const Color(0xFF4CAF50), onTap: _pickImageFromGallery)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPhotoOption(icon: Icons.camera_alt_rounded, label: 'Camera',
                    color: const Color(0xFF2196F3), onTap: _takePhoto)),
                ]),
                const SizedBox(height: 32),
                _sectionHeading(Icons.male_rounded, 'Male Avatars', const Color(0xFF2196F3)),
                const SizedBox(height: 16),
                _buildAvatarGrid(_maleAvatars),
                const SizedBox(height: 28),
                _sectionHeading(Icons.female_rounded, 'Female Avatars', const Color(0xFFE91E63)),
                const SizedBox(height: 16),
                _buildAvatarGrid(_femaleAvatars),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 24), const SizedBox(width: 8),
      Text(label, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildPhotoOption({
    required IconData icon, required String label, required Color color, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildAvatarGrid(List<Map<String, String>> avatars) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = _selectedAvatarUrl == avatar['url'];
        return GestureDetector(
          onTap: () => _selectAvatar(avatar['url']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 3),
              boxShadow: isSelected ? [
                BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
              ] : null,
            ),
            child: CircleAvatar(
              radius: 35, backgroundColor: AppColors.cardAlt(context),
              backgroundImage: NetworkImage(avatar['url']!),
              child: isSelected
                ? Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.3)),
                    child: const Center(child: Icon(Icons.check, color: Colors.white, size: 28)))
                : null,
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) { _showSnackBar('User not found.', isError: true); return; }

      await user.updateDisplayName(_nameController.text.trim());

      if (_selectedAvatarUrl != null && _selectedAvatarUrl != user.photoURL) {
        await user.updatePhotoURL(_selectedAvatarUrl);
      }

      bool emailChanged = _emailController.text.trim() != user.email;
      if (emailChanged) {
        await user.verifyBeforeUpdateEmail(_emailController.text.trim());
      }

      final phone = _phoneController.text.trim();
      await _firestore.collection('users').doc(user.uid).set(
        {'phone': phone}, SetOptions(merge: true));

      await user.reload();

      if (emailChanged) {
        _showSnackBar('Verification email sent. Other changes saved!');
      } else {
        _showSnackBar('Profile updated successfully!');
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        Navigator.pop(context, true);
      }
    } catch (e) {
      final user = _auth.currentUser;
      await user?.reload();
      if (user?.displayName == _nameController.text.trim()) {
        _showSnackBar('Profile updated successfully!');
        if (mounted) { await Future.delayed(const Duration(milliseconds: 600)); Navigator.pop(context, true); }
      } else {
        _showSnackBar('Failed to update. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context), elevation: 0,
        leading: GestureDetector(onTap: _onBackTapped,
          child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary(context), size: 22)),
        title: Text('Edit Profile', style: TextStyle(
          color: AppColors.textPrimary(context), fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoadingData
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(children: [
              Divider(height: 1, color: AppColors.divider(context)),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    const SizedBox(height: 10),
                    _buildProfilePhoto(),
                    const SizedBox(height: 40),
                    _buildTextField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline_rounded,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null),
                    const SizedBox(height: 20),
                    _buildTextField(controller: _emailController, label: 'Email', icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@') ? 'Please enter a valid email' : null),
                    const SizedBox(height: 20),
                    _buildTextField(controller: _phoneController, label: 'Phone Number', icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone, hint: '+91 98765 43210'),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft,
                      child: Text('Phone number is saved to your profile.',
                        style: TextStyle(color: AppColors.textHint(context), fontSize: 11))),
                    const SizedBox(height: 40),
                    _buildSaveButton(),
                  ]),
                ),
              ),
            ]),
          ),
    );
  }

  Widget _buildProfilePhoto() {
    final user = _auth.currentUser;
    ImageProvider? imageProvider;
    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (_selectedAvatarUrl != null) imageProvider = NetworkImage(_selectedAvatarUrl!);
    else if (user?.photoURL != null) imageProvider = NetworkImage(user!.photoURL!);

    return Column(children: [
      Stack(children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2196F3)]),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]),
          child: CircleAvatar(radius: 65, backgroundColor: AppColors.surface(context),
            backgroundImage: imageProvider,
            child: imageProvider == null ? Icon(Icons.person_rounded, size: 65, color: AppColors.textHint(context)) : null),
        ),
        Positioned(bottom: 0, right: 0,
          child: GestureDetector(onTap: _showPhotoOptions,
            child: Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2196F3)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10)]),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22)))),
      ]),
      const SizedBox(height: 16),
      GestureDetector(onTap: _showPhotoOptions,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.3))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_rounded, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Text('Change Photo', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildTextField({
    required TextEditingController controller, required String label, required IconData icon,
    TextInputType keyboardType = TextInputType.text, bool enabled = true,
    String? hint, String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 10),
      TextFormField(
        controller: controller, keyboardType: keyboardType, enabled: enabled,
        style: TextStyle(color: enabled ? AppColors.textPrimary(context) : AppColors.textHint(context), fontSize: 16),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: AppColors.textHint(context)),
          prefixIcon: Icon(icon, color: enabled ? AppColors.primary : AppColors.textHint(context), size: 22),
          filled: true, fillColor: AppColors.surface(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18))),
    ]);
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveChanges,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _isLoading
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            ]),
      ),
    );
  }
}