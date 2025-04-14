import 'package:secureher/utils/quotes.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget {
  final VoidCallback onTap;
  final int quoteIndex;
  final VoidCallback onLogout;

  const CustomAppBar({
    Key? key,
    required this.onTap,
    required this.quoteIndex,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // TODO: Implement menu functionality
          },
        ),
        GestureDetector(
          onTap: onTap,
          child: const Icon(Icons.refresh),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: onLogout,
        ),
      ],
    );
  }
}
