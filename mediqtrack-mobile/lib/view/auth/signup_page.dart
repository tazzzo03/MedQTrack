// lib/views/auth/signup_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../controller/signup_controller.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _gender;

  final SignUpController _signupController = SignUpController();

  bool _obscure = true;
  bool _acceptedTos = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _icCtrl.dispose();
    _dobCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  void _doSignUp() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sila isi semua ruangan dengan betul.')));
      return;
    }
    if (!_acceptedTos) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please agree to the Terms & Privacy Policy.')));
      return;
    }

    setState(() => _loading = true);

    final user = await _signupController.signUp(
      name: _nameCtrl.text.trim(),
      icNumber: _icCtrl.text.trim(),
      dob: _dobCtrl.text.trim(),
      gender: _gender ?? '',
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      phone: _phoneCtrl.text.trim(),
      context: context,
    );

    setState(() => _loading = false);

    if (user != null && mounted) {
      Navigator.of(context).pop(); // balik ke login page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FA),
      appBar: AppBar(
        title: const Text('Patient Registration'),
        backgroundColor: Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama diperlukan' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _icCtrl,
                decoration: const InputDecoration(
                  labelText: 'IC Number',
                  prefixIcon: const Icon(Icons.credit_card_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'No. IC diperlukan' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _dobCtrl,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Tarikh lahir diperlukan' : null,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: const Icon(Icons.wc_outlined),
                ),
                onChanged: (val) => setState(() => _gender = val),
                validator: (v) => (v == null || v.isEmpty) ? 'Pilih jantina' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'No. telefon diperlukan' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email diperlukan';
                  if (!v.contains('@')) return 'Masukkan email sah';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 aksara' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _acceptedTos,
                    onChanged: (v) => setState(() => _acceptedTos = v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'I agree to the Terms & Privacy Policy',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              FilledButton(
                onPressed: _loading ? null : _doSignUp,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Account'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Login'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
