import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naham_app/core/constants/app_constants.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/dish_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:naham_app/providers/dish_provider.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  List<DishModel> _searchResults = [];
  String _selectedCategory = 'all';
  bool _isSearching = false;

  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
    });

    final dishes = context.read<DishProvider>().customerDishes;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        if (query.isEmpty && _selectedCategory == 'all') {
          _searchResults = [];
        } else {
          _searchResults = dishes.where((dish) {
            final matchesQuery = query.isEmpty ||
                dish.name.toLowerCase().contains(query.toLowerCase()) ||
                dish.description.toLowerCase().contains(query.toLowerCase());

            final matchesCategory = _selectedCategory == 'all' ||
                dish.categoryId == _selectedCategory;

            return matchesQuery && matchesCategory;
          }).toList();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header & Search Bar ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Search',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _performSearch,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search dishes or ingredients...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textHint),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.textHint),
                              onPressed: () {
                                _searchCtrl.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Filters ───
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildFilterChip('all'),
                  ...AppConstants.foodCategories
                      .map((cat) => _buildFilterChip(cat['id']!)),
                ],
              ),
            ),

            // ─── Results ───
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty && _searchCtrl.text.isNotEmpty
                      ? _buildEmptyState()
                      : _searchResults.isEmpty
                          ? _buildInitialState()
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                return _SearchResultTile(
                                    dish: _searchResults[index]);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    // For mock mapping
    String displayLabel = label;
    if (label != 'all') {
      final match = AppConstants.foodCategories.firstWhere(
        (c) => c['id'] == label,
        orElse: () => {'name': label},
      );
      displayLabel = match['name'] ?? label;
    }

    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(displayLabel),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedCategory = label;
          });
          _performSearch(_searchCtrl.text);
        },
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'No matching results found',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different words',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_rounded, size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          const Text(
            'Search for your favorite meal',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'More homemade dishes are waiting for you',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final DishModel dish;
  const _SearchResultTile({required this.dish});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.dishDetail}/${dish.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: dish.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dish.cookName,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${dish.price} SAR',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: AppColors.warning, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            dish.rating.toString(),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
