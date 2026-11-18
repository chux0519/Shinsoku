import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ShinsokuMark(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class ShinsokuMark extends StatelessWidget {
  const ShinsokuMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/app-icon.png',
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surface,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.inbox_outlined, size: 44),
        SizedBox(height: 12),
        Text('No drafts yet'),
      ],
    );
  }
}
