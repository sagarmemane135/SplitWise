import 'package:flutter/material.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, required this.onSubmit});

  final Future<String?> Function({required String displayName, required String currencyCode})
      onSubmit;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController(text: 'INR');
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Welcome to Splitwise', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Create your local profile once. Your details are saved on device and reused while creating or joining groups.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your display name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currencyController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Preferred currency code *',
                  hintText: 'INR, USD, EUR',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_isSaving ? 'Saving...' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final String? error = await widget.onSubmit(
      displayName: _nameController.text,
      currencyCode: _currencyController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _error = error;
    });
  }
}
