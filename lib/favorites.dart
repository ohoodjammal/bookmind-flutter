import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore {
  static const String key = 'favorite_book_ids';

  // changed
  static Future<Set<String>> getIds() async {
    final prefs = await SharedPreferences.getInstance();

    return (prefs.getStringList(key) ?? []).toSet();
  }

  // changed
  static Future<bool> contains(dynamic id) async {
    final ids = await getIds();

    return ids.contains(id.toString());
  }

  // changed
  static Future<void> setFavorite(dynamic id, bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();

    final ids = (prefs.getStringList(key) ?? []).toSet();

    if (isFavorite) {
      ids.add(id.toString());
    } else {
      ids.remove(id.toString());
    }

    await prefs.setStringList(key, ids.toList());
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<dynamic> books = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    loadFavorites();
  }

  Future<void> loadFavorites() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final ids = await FavoritesStore.getIds();

      final favoriteBooks = <dynamic>[];

      for (final id in ids) {
        final response = await http.get(
          Uri.parse('https://www.dbooks.org/api/book/$id'),
        );

        if (response.statusCode != 200) {
          continue;
        }

        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic> && data['status'] != 'error') {
          favoriteBooks.add(data);
        }
      }

      if (!mounted) return;

      setState(() {
        books = favoriteBooks;
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

  Future<void> removeFavorite(dynamic id) async {
    await FavoritesStore.setFavorite(id, false);

    if (!mounted) return;

    setState(() {
      books.removeWhere((book) => book['id'].toString() == id.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // changed

      appBar: AppBar(
        title: const Text('Favorites'),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // changed
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(errorMessage!, textAlign: TextAlign.center),
                  ),
                  ElevatedButton(
                    onPressed: loadFavorites,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : books.isEmpty
          ? Center(
              // changed: make the empty Favorites state clear and inviting.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Color.fromARGB(255, 198, 115, 70),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorite books yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Save books you love and find them here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),

              itemCount: books.length,

              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.60,
              ),

              itemBuilder: (context, index) {
                final book = books[index];

                return Card(
                  elevation: 5,

                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(15),
                            topRight: Radius.circular(15),
                          ),

                          child: Image.network(
                            book['image'] ?? '',
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),

                        child: Text(
                          book['title'] ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      IconButton(
                        tooltip: 'Remove from favorites',

                        icon: const Icon(Icons.favorite, color: Colors.red),

                        onPressed: () {
                          removeFavorite(book['id']);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
