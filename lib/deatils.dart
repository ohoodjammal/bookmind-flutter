import 'dart:convert';

import 'package:books_app/disc.dart';
import 'package:books_app/favorites.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class Deatils extends StatefulWidget {
  final dynamic id;

  const Deatils({super.key, required this.id});

  @override
  State<Deatils> createState() => _DeatilsState();
}

class _DeatilsState extends State<Deatils> {
  Map<String, dynamic> myData = {};
  bool isLoading = true;
  bool isFavorite = false;
  String? errorMessage;

  Future<void> getId() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse('https://www.dbooks.org/api/book/${widget.id}');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('API request failed');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> ||
          decoded['status'] == 'error' ||
          decoded['title'] == null) {
        throw Exception('Invalid API response');
      }

      if (!mounted) return;

      setState(() {
        myData = decoded;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Something went wrong. Please check your connection and try again.';
      });
    }
  }

  Future<void> _loadFavorite() async {
    final saved = await FavoritesStore.contains(widget.id);

    if (mounted) {
      setState(() {
        isFavorite = saved;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    // changed
    final nextValue = !isFavorite;

    await FavoritesStore.setFavorite(widget.id, nextValue);

    if (mounted) {
      setState(() {
        isFavorite = nextValue;
      });
    }
  }

  // changed: share the book title and URL using share_plus.
  Future<void> _shareBook() async {
    final bookUrl = myData['url']?.toString();

    if (bookUrl == null || bookUrl.isEmpty) {
      return;
    }

    final title = myData['title']?.toString() ?? 'BookMind book'; // changed

    await Share.share('$title\n$bookUrl'); // changed
  }

  @override
  void initState() {
    super.initState();

    getId();
    _loadFavorite();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 198, 115, 70),
          title: const Text('Error'),
        ),

        // changed: ErrorView is now inside this file.
        // changed: keep detail errors themed while preserving retry.
        body: ErrorView(
          message: errorMessage!,
          onRetry: getId,
        ),
      );
    }

    if (myData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 198, 115, 70),
          title: const Text('Error'),
        ),

        // changed
        body: ErrorView(
          message:
              'Something went wrong. Please check your connection and try again.',
          onRetry: getId,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 198, 115, 70),

        actions: [
          // changed: share button
          IconButton(
            tooltip: 'Share book',
            icon: const Icon(
              Icons.share,
              color: Colors.white,
            ),
            onPressed: _shareBook,
          ),

          // changed: favorite button
          IconButton(
            tooltip: isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',

            icon: Icon(
              isFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: isFavorite
                  ? Colors.red
                  : Colors.white,
            ),

            onPressed: _toggleFavorite,
          ),

          const Icon(Icons.more_vert),
        ],

        title: const Text(
          'Book Details',
          style: TextStyle(
            color: Color.fromARGB(255, 255, 244, 229),
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.only(
          top: 20,
          left: 16,
          right: 16,
        ),

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Image.network(
                myData['image'] ?? '',
                width: 150,
                fit: BoxFit.cover,
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      myData['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      myData['subtitle'] ?? '',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 198, 115, 70),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_sharp,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          myData['year']?.toString() ?? '',
                        ),

                        const SizedBox(width: 10),

                        const Icon(
                          Icons.difference_rounded,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          myData['pages']?.toString() ?? '',
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: const Color.fromARGB(
                          255,
                          198,
                          115,
                          70,
                        ),
                      ),

                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),

                        child: Text(
                          'Genre : Fiction',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Text(
            'description',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            myData['description'] ?? '',
          ),

          TextButton(
            onPressed: () {
              Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (context) => Disc(
                    description:
                        myData['description'] ?? '',
                  ),
                ),
              );
            },

            child: const Text(
              'Read More',
              style: TextStyle(
                color: Color.fromARGB(255, 198, 115, 70),
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Divider(),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: const [
                  Text(
                    'Publisher',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    'Publisher Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    'ISBN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    myData['publisher'] ?? '',
                  ),

                  Text(
                    myData['year']?.toString() ?? '',
                  ),

                  Text(
                    myData['id']?.toString() ?? '',
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(
                255,
                198,
                115,
                70,
              ),
            ),

            onPressed: () async {
              if (myData['url'] != null) {
                final url = Uri.parse(
                  myData['url'],
                );

                await launchUrl(url);
              }
            },

            child: const ListTile(
              leading: Icon(
                Icons.menu_book,
                color: Colors.white,
              ),

              title: Text(
                'View Book',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// changed: ErrorView is now independent from Favorites.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: Color.fromARGB(
                255,
                198,
                115,
                70,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              message,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}