import 'package:flutter/material.dart';

class Disc extends StatefulWidget {
  final String description;
  const Disc({super.key, required this.description});

  @override
  State<Disc> createState() => _DiscState();
}

class _DiscState extends State<Disc> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 198, 115, 70),
        title: Text('description'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(widget.description),
        ),
      ),
    );
  }
}
