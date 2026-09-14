import 'dart:convert';
import 'package:books_app/deatils.dart';
import 'package:books_app/favorites.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.light,
);
const orangeColor = Color.fromARGB(255, 198, 115, 70);
const lightBackgroundColor = Color.fromARGB(255, 255, 244, 229);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Homepage()),
      );
    });
  }

  @override
  void dispose() {
    // changed
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        // changed
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // changed
            SizedBox.expand(
              child: Image.asset('assets/images/splash.jpg', fit: BoxFit.cover),
            ),

            // changed
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    // changed: restore the user's theme choice when the app starts.
    final preferences = await SharedPreferences.getInstance();
    themeModeNotifier.value = preferences.getBool('dark_mode') == true
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: orangeColor,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: lightBackgroundColor,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: orangeColor,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Us'),
        backgroundColor: orangeColor,
        foregroundColor: lightBackgroundColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book, size: 72, color: orangeColor),
              const SizedBox(height: 20),
              Text(
                'BookMind',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: orangeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'BookMind is a Flutter book application that helps you explore '
                'books, search for books, view book details, and save books '
                'to Favorites.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  bool isLoading = false;
  bool isSearching = false;
  String searchQuery = '';
  // changed: keep the selected category alongside the existing search state.
  String selectedCategory = 'All';
  dynamic myData;
  bool isError = false;
  String errorMessage =
      'Something went wrong. Please check your connection and try again.';

  Future<void> getData() async {
    // changed: every API failure now reaches a retryable error state.
    setState(() {
      isLoading = true;
      isError = false;
    });
    try {
      final url = Uri.parse('https://www.dbooks.org/api/recent');
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('API request failed');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['books'] is! List ||
          (decoded['books'] as List).isEmpty) {
        throw Exception('Invalid or empty API response');
      }
      if (!mounted) return;
      setState(() {
        myData = decoded;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  List<dynamic> get filteredBooks {
    final books = categoryFilteredBooks;
    final query = searchQuery.trim().toLowerCase();

    return books.where((book) {
      final title = (book['title'] ?? '').toString().toLowerCase();
      final matchesSearch = query.isEmpty || title.contains(query);
      return matchesSearch;
    }).toList();
  }

  // changed: keep suggestions available when a search has no exact matches.
  List<dynamic> get categoryFilteredBooks {
    final books = (myData?['books'] as List<dynamic>?) ?? [];
    return books
        .where(
          (book) =>
              selectedCategory == 'All' ||
              _bookCategory(book) == selectedCategory,
        )
        .toList();
  }

  // changed: derive simple categories from metadata returned by dbooks.org.
  String _bookCategory(dynamic book) {
    final explicitCategory = book['category'] ?? book['genre'];
    if (explicitCategory is String && explicitCategory.trim().isNotEmpty) {
      return explicitCategory.trim();
    }
    if (book['categories'] is List && (book['categories'] as List).isNotEmpty) {
      return (book['categories'] as List).first.toString();
    }

    final metadata = [
      book['title'],
      book['subtitle'],
      book['authors'],
    ].join(' ').toLowerCase();
    const categoryKeywords = <String, List<String>>{
      'Technology': [
        'software',
        'programming',
        'computer',
        'technology',
        'data',
        'web',
        'cloud',
        'security',
        'python',
        'java',
      ],
      'Business': [
        'business',
        'finance',
        'investment',
        'management',
        'marketing',
        'economics',
      ],
      'Science': [
        'science',
        'physics',
        'chemistry',
        'biology',
        'mathematics',
        'medical',
      ],
      'History': ['history', 'historical', 'war', 'civilization'],
      'Fiction': ['novel', 'fiction', 'story', 'tales', 'mystery', 'fantasy'],
      'Self-Help': [
        'self-help',
        'success',
        'leadership',
        'mindfulness',
        'personal development',
      ],
    };
    for (final entry in categoryKeywords.entries) {
      if (entry.value.any(metadata.contains)) {
        return entry.key;
      }
    }
    return 'Other';
  }

  // changed: expose only categories represented by the loaded API results.
  List<String> get availableCategories {
    final categories = <String>{'All'};
    final books = (myData?['books'] as List<dynamic>?) ?? [];
    for (final book in books) {
      categories.add(_bookCategory(book));
    }
    return categories.toList();
  }

  String? get suggestedBookTitle {
    // changed: keep smart suggestions scoped to the selected category.
    final books = categoryFilteredBooks;
    if (books.isEmpty || searchQuery.trim().isEmpty) {
      return null;
    }

    final query = searchQuery.trim().toLowerCase();
    var closestTitle = '';
    int? closestDistance;

    for (final book in books) {
      final title = (book['title'] ?? '').toString();
      final distance = _similarityDistance(query, title.toLowerCase());
      if (closestDistance == null || distance < closestDistance) {
        closestDistance = distance;
        closestTitle = title;
      }
    }

    return closestTitle.isEmpty ? null : closestTitle;
  }

  int _similarityDistance(String first, String second) {
    final distances = List<int>.generate(second.length + 1, (index) => index);

    for (var i = 1; i <= first.length; i++) {
      var previous = distances[0];
      distances[0] = i;
      for (var j = 1; j <= second.length; j++) {
        final current = distances[j];
        final substitutionCost = first[i - 1] == second[j - 1] ? 0 : 1;
        distances[j] = [
          distances[j] + 1,
          distances[j - 1] + 1,
          previous + substitutionCost,
        ].reduce((a, b) => a < b ? a : b);
        previous = current;
      }
    }

    return distances[second.length];
  }

  @override
  Widget build(BuildContext context) {
    final books = filteredBooks;
    final suggestion = suggestedBookTitle;

    return Scaffold(
      // changed: the Drawer provides favorites and persisted theme switching.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: orangeColor),
              child: Text(
                'BookMind',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: lightBackgroundColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoritesScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Us'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutUsPage()),
                );
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              value: themeModeNotifier.value == ThemeMode.dark,
              onChanged: (enabled) async {
                final mode = enabled ? ThemeMode.dark : ThemeMode.light;
                themeModeNotifier.value = mode;
                final preferences = await SharedPreferences.getInstance();
                await preferences.setBool('dark_mode', enabled);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        actions: [
          if (isSearching)
            SizedBox(
              width: 220,
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search books',
                  hintStyle: TextStyle(
                    color: Color.fromARGB(255, 255, 244, 229),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.search,
                color: Color.fromARGB(255, 255, 244, 229),
              ),
              onPressed: () {
                setState(() {
                  isSearching = true;
                });
              },
            ),
          if (isSearching)
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Color.fromARGB(255, 255, 244, 229),
              ),
              onPressed: () {
                setState(() {
                  isSearching = false;
                  searchQuery = '';
                });
              },
            ),
        ],
        title: Text(
          'BookMind',
          style: TextStyle(color: const Color.fromARGB(255, 255, 244, 229)),
        ),
        centerTitle: true,
        backgroundColor: orangeColor,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : isError
          ? _HomeErrorState(message: errorMessage, onRetry: getData)
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // changed: filter the loaded books without changing the API.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButtonFormField<String>(
                      // changed: use the current category as the field value.
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: availableCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (category) {
                        if (category == null) return;
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child:
                        books.isEmpty &&
                            (searchQuery.trim().isNotEmpty ||
                                selectedCategory != 'All')
                        ? _NoBooksFoundState(suggestion: suggestion)
                        : GridView.builder(
                            itemCount: books.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.60,
                                ),
                            itemBuilder: (context, index) {
                              var book = books[index];
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            Deatils(id: book['id']),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    elevation: 5,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(15),
                                                  topRight: Radius.circular(15),
                                                ),
                                            child: Image.network(
                                              book['image']?.toString() ?? '',
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            book['title']?.toString() ?? '',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            book['authors']?.toString() ?? '',
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color.fromARGB(
                                                255,
                                                198,
                                                115,
                                                70,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// changed: keep Home API failures clear while preserving the existing retry.
class _HomeErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HomeErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: orangeColor),
            const SizedBox(height: 16),
            Text(
              'Unable to load books',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
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

// changed: provide a themed empty state without removing smart suggestions.
class _NoBooksFoundState extends StatelessWidget {
  final String? suggestion;

  const _NoBooksFoundState({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 64, color: orangeColor),
          const SizedBox(height: 16),
          Text(
            suggestion == null
                ? 'No books found'
                : 'No books found\nDid you mean "$suggestion"?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
