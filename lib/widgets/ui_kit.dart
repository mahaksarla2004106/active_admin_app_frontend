import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget>? actions;
  const PageHeader({super.key, required this.title, this.subtitle = '', this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF0F1E2E))),
              if (subtitle.isNotEmpty) const SizedBox(height: 4),
              if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF5A6B7B))),
            ]),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F1E2E))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF5A6B7B))),
        ]),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status.toUpperCase()) {
      case 'PUBLISHED':
      case 'ACTIVE':
      case 'CONFIRMED':
      case 'CAPTURED':
      case 'APPROVED':
      case 'PROCESSED':
      case 'RESOLVED':
      case 'OPEN':
      case 'PENDING':
        return const Color(0xFF00B892);
      case 'FAILED':
      case 'CANCELLED':
      case 'SUSPENDED':
      case 'REJECTED':
      case 'BLOCKED':
      case 'DELETED':
      case 'ARCHIVED':
        return const Color(0xFFD32F2F);
      case 'PENDING_PAYMENT':
      case 'REFUND_PENDING':
      case 'IN_PROGRESS':
      case 'INACTIVE':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final ValueChanged<int> onChanged;
  const PaginationBar({super.key, required this.page, required this.totalPages, required this.total, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$total items', style: const TextStyle(color: Color(0xFF5A6B7B), fontSize: 13)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: page > 1 ? () => onChanged(page - 1) : null, icon: const Icon(Icons.chevron_left, size: 20)),
            Text('$page / ${totalPages == 0 ? 1 : totalPages}', style: const TextStyle(color: Color(0xFF0F1E2E), fontWeight: FontWeight.w600)),
            IconButton(onPressed: page < totalPages ? () => onChanged(page + 1) : null, icon: const Icon(Icons.chevron_right, size: 20)),
          ]),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  const SearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE4E9EF))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE4E9EF))),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class LoadingBox extends StatelessWidget {
  final String message;
  const LoadingBox({super.key, this.message = 'Loading...'});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Color(0xFF5A6B7B))),
        ]),
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorBox({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0F1E2E))),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? const Color(0xFFD32F2F) : const Color(0xFF00B892), behavior: SnackBarBehavior.floating));
}