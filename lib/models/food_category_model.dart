class FoodCategoryModel {
  const FoodCategoryModel({
    required this.id,
    required this.label,
    required this.title,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String title;
  final String assetPath;
}

class NahamFoodCategories {
  const NahamFoodCategories._();

  static const all = <FoodCategoryModel>[
    FoodCategoryModel(
      id: 'all',
      label: 'All',
      title: 'All Dishes',
      assetPath: 'assets/images/all_saudi_arabia.png',
    ),
    FoodCategoryModel(
      id: 'northern',
      label: 'Northern',
      title: 'Northern Dishes',
      assetPath: 'assets/images/al_shamalia.png',
    ),
    FoodCategoryModel(
      id: 'eastern',
      label: 'Eastern',
      title: 'Eastern Dishes',
      assetPath: 'assets/images/al_sharqia.png',
    ),
    FoodCategoryModel(
      id: 'southern',
      label: 'Southern',
      title: 'Southern Dishes',
      assetPath: 'assets/images/al_janobia.png',
    ),
    FoodCategoryModel(
      id: 'najdi',
      label: 'Najdi',
      title: 'Najdi Dishes',
      assetPath: 'assets/images/al_najdia.png',
    ),
    FoodCategoryModel(
      id: 'western',
      label: 'Western',
      title: 'Western Dishes',
      assetPath: 'assets/images/al_garbia.png',
    ),
    FoodCategoryModel(
      id: 'sweets',
      label: 'Sweets',
      title: 'Sweets',
      assetPath: 'assets/images/cookie.png',
    ),
    FoodCategoryModel(
      id: 'baked',
      label: 'Baked',
      title: 'Baked Goods',
      assetPath: 'assets/images/baked.png',
    ),
  ];

  static FoodCategoryModel byId(String id) {
    return all.firstWhere(
      (category) => category.id == id,
      orElse: () => all.first,
    );
  }
}
