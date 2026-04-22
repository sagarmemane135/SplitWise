import 'package:flutter/material.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.people_outline, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Add friends to SplitEase',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'You have no friends to show yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
