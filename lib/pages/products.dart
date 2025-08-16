import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:badges/badges.dart' as badges;
import 'package:badges/badges.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos_final/helpers/icons.dart';

import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/generators.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/database.dart';
import '../models/product_model.dart';
import '../models/sell.dart';
import '../models/system.dart';
import '../models/variations.dart';
import 'elements.dart';

class Products extends StatefulWidget {
  @override
  _ProductsState createState() => _ProductsState();
}

class _ProductsState extends State<Products> {
  List products = [];
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  late DbProvider dbProvider;
  bool changeLocation = false,
      changePriceGroup = false,
      canChangeLocation = true,
      canMakeSell = false,
      inStock = true,
      gridView = false,
      canAddSell = false,
      canViewProducts = false,
      usePriceGroup = true,
      isLoading = false,
      _isRefreshing = false;

  int selectedLocationId = 0,
      categoryId = 0,
      subCategoryId = 0,
      brandId = 0,
      cartCount = 0,
      sellingPriceGroupId = 0,
      offset = 0;
  int? byAlphabets, byPrice;

  List<DropdownMenuItem<int>> _categoryMenuItems = [],
      _subCategoryMenuItems = [],
      _brandsMenuItems = [];
  List<DropdownMenuItem<bool>> _priceGroupMenuItems = [];
  Map? argument;
  List<Map<String, dynamic>> locationListMap = [
    {'id': 0, 'name': 'set location', 'selling_price_group_id': 0}
  ];

  String symbol = '';
  String url =
      'https://www.youtube.com/watch?v=l3Jvigvxsvc&ab_channel=TheInspiringDad';
  final searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  ScrollController _scrollController = new ScrollController();
  Timer? _searchDebouncer;
  bool hasReachedMax = false;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    searchController.dispose();
    _scrollController.dispose();
    _searchDebouncer?.cancel();
    _scrollDebouncer?.cancel();
    super.dispose();
  }

  Timer? _scrollDebouncer;
  @override
  initState() {
    super.initState();
    dbProvider = DbProvider();
    // Enable all permissions by default
    canAddSell = true;
    canViewProducts = true;

    _scrollController.addListener(() {
      if (_scrollDebouncer?.isActive ?? false) _scrollDebouncer?.cancel();

      _scrollDebouncer = Timer(const Duration(milliseconds: 300), () {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
            !isLoading &&
            !hasReachedMax) {
          productList();
        }
      });
    });

    setLocationMap();
    categoryList();
    subCategoryList(categoryId);
    brandList();
    Helper().syncCallLogs();
  }
  @override
  Future<void> didChangeDependencies() async {
    argument = ModalRoute.of(context)!.settings.arguments as Map?;
    if (argument != null) {
      Future.delayed(Duration(milliseconds: 200), () {
        if (this.mounted) {
          setState(() {
            selectedLocationId = argument!['locationId'];
            canChangeLocation = false;
          });
        }
      });
    } else {
      canChangeLocation = true;
    }
    await setInitDetails(selectedLocationId);
    super.didChangeDependencies();
  }


  Future<void> syncProducts() async {
    if (!mounted || isLoading) return;

    // Check internet connectivity first
    bool hasConnectivity = await Helper().checkConnectivity();
    if (!hasConnectivity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No internet connection available for sync'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    // Store current data in case sync fails
    List currentProducts = List.from(products);
    int currentOffset = offset;
    bool currentHasReachedMax = hasReachedMax;

    try {
      // Force sync from server first - don't clear cache until this succeeds
      await Variations().refresh();
      await System().insertProductLastSyncDateTimeNow();

      // Only clear existing data after successful sync
      setState(() {
        products = [];
        offset = 0;
        hasReachedMax = false;
      });

      // Reload data
      await productList();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text(AppLocalizations.of(context).translate('sync_complete'))),
      );
    } catch (e) {
      // Restore previous data if sync failed
      setState(() {
        products = currentProducts;
        offset = currentOffset;
        hasReachedMax = currentHasReachedMax;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${AppLocalizations.of(context).translate('sync_failed')}: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    // Store current data in case we need to restore it
    List currentProducts = List.from(products);
    int currentOffset = offset;
    bool currentHasReachedMax = hasReachedMax;

    try {
      // Check internet connectivity before clearing cache
      bool hasConnectivity = await Helper().checkConnectivity();

      if (hasConnectivity) {
        // Only clear products if we have internet connection
        setState(() {
          products = [];
          offset = 0;
          hasReachedMax = false;
        });

        await productList();
      } else {
        // No internet, just reload from existing cache
        print('No internet connection - refreshing from cache only');
        setState(() {
          products = [];
          offset = 0;
          hasReachedMax = false;
        });
        await productList();
      }
    } catch (e) {
      // If refresh fails, restore previous data
      print('Refresh failed, restoring previous data: $e');
      setState(() {
        products = currentProducts;
        offset = currentOffset;
        hasReachedMax = currentHasReachedMax;
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _onSearchChanged() {
    if (_searchDebouncer?.isActive ?? false) _searchDebouncer?.cancel();

    _searchDebouncer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      setState(() {
        products = [];
        offset = 0;
        hasReachedMax = false;
      });
      productList();
    });
  }


  //Set location & product
  setInitDetails(selectedLocationId) async {
    // Enable sell functionality by default
    setState(() {
      canMakeSell = true;
    });

    await Helper().getFormattedBusinessDetails().then((value) {
      symbol = value['symbol'] + ' ';
    });

    await setDefaultLocation(selectedLocationId).then((_) {
      bool hasGroup = locationListMap.any((element) =>
      element['id'] == selectedLocationId &&
          element['selling_price_group_id'] != null);

      setState(() {
        usePriceGroup = hasGroup;
      });
    });

    // Reset pagination and products
    setState(() {
      products = [];
      offset = 0;
      hasReachedMax = false;
    });

    // Check connectivity and initialize data accordingly
    bool hasConnectivity = await Helper().checkConnectivity();
    if (hasConnectivity) {
      print('Initial setup - Online mode');
      // Force sync to ensure we have latest data
      try {
        await Variations().refresh();
        await System().insertProductLastSyncDateTimeNow();
        print('Data initialized successfully for offline use');
      } catch (e) {
        print('Error during initial data sync: $e');
      }
    } else {
      print('Initial setup - Offline mode');
    }

    // Load products
    productList();
  }



  //set selling Price Group Id
  findSellingPriceGroupId(locId) {
    if (usePriceGroup) {
      locationListMap.forEach((element) {
        if (element['id'] == selectedLocationId &&
            element['selling_price_group_id'] != null) {
          sellingPriceGroupId =
              int.parse(element['selling_price_group_id'].toString());
        } else if (element['id'] == selectedLocationId &&
            element['selling_price_group_id'] == null) {
          sellingPriceGroupId = 0;
        }
      });
    } else {
      sellingPriceGroupId = 0;
    }
  }

  // Helper method to convert dynamic maps to String-keyed maps
  List<Map<String, dynamic>> convertToStringKeyMapList(List<Map<dynamic, dynamic>> dynamicList) {
    return dynamicList.map((item) {
      Map<String, dynamic> convertedMap = {};
      item.forEach((key, value) {
        convertedMap[key.toString()] = value;
      });
      return convertedMap;
    }).toList();
  }

  // Calculate stock available for cached products (offline mode)
  Future<int> _calculateStockAvailable(Map<String, dynamic> product) async {
    try {
      // If stock is not enabled, return 9999 (unlimited)
      if (product['enable_stock'] == 0) {
        return 9999;
      }

      // For offline mode, use the stock_available from the cached product if available
      if (product['stock_available'] != null) {
        return int.parse(product['stock_available'].toString());
      }

      // Fallback: Get base quantity from variations_location_details
      int baseQty = 0;
      if (product['qty_available'] != null) {
        baseQty = double.parse(product['qty_available'].toString()).toInt();
      }

      // Try to get sold quantity from sell_lines for this location (with error handling)
      try {
        final db = await dbProvider.database;
        String productLastSync = await System().getProductLastSync();

        var soldQtyResult = await db.rawQuery('''
          SELECT COALESCE(SUM(SL.quantity), 0) as sold_qty 
          FROM sell_lines AS SL 
          JOIN sell AS S ON SL.sell_id = S.id
          WHERE (SL.is_completed = 0 OR S.transaction_date > ?) 
          AND S.location_id = ? 
          AND SL.variation_id = ? 
          AND S.is_quotation = 0
        ''', [productLastSync, selectedLocationId, product['variation_id']]);

        int soldQty = 0;
        if (soldQtyResult.isNotEmpty) {
          soldQty = int.parse(soldQtyResult[0]['sold_qty'].toString());
        }

        // Calculate available stock
        int stockAvailable = baseQty - soldQty;
        return stockAvailable > 0 ? stockAvailable : 0;
      } catch (dbError) {
        print('Database error calculating stock: $dbError');
        // Return base quantity if database query fails
        return baseQty > 0 ? baseQty : 0;
      }
    } catch (e) {
      print('Error calculating stock: $e');
      return 0;
    }
  }

  // Load products from cache for offline mode
  Future<void> _loadProductsFromCache() async {
    if (_isDisposed || !mounted) return;

    print('Loading products from cache for offline mode');

    try {
      findSellingPriceGroupId(selectedLocationId);

      // Use the existing database query method but for cached data
      final cachedProducts = await Variations().get(
        brandId: brandId,
        categoryId: categoryId,
        subCategoryId: subCategoryId,
        inStock: inStock,
        locationId: selectedLocationId,
        searchTerm: searchController.text,
        offset: offset,
        byAlphabets: byAlphabets,
        byPrice: byPrice,
      );

      if (_isDisposed || !mounted) return;

      if (cachedProducts.isNotEmpty) {
        for (var product in cachedProducts) {
          if (_isDisposed || !mounted) return;

          var price;
          if (product['selling_price_group'] != null) {
            jsonDecode(product['selling_price_group']).forEach((element) {
              if (element['key'] == sellingPriceGroupId) {
                price = double.parse(element['value'].toString());
              }
            });
          }

          if (_isDisposed || !mounted) return;
          setState(() {
            products.add(ProductModel().product(product, price));
          });
        }

        // Check if we reached the end based on page size
        if (cachedProducts.length < 10) { // Less than expected page size
          setState(() {
            hasReachedMax = true;
          });
        }
      } else {
        // Check if this is the first page or we have no data at all
        if (offset == 1) {
          // No cached products available at all
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${AppLocalizations.of(context).translate("no_products_found")} - Please connect to internet to sync data'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }

        if (_isDisposed || !mounted) return;
        setState(() {
          hasReachedMax = true;
        });
      }
    } catch (e) {
      print('Error loading products from cache: $e');

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading offline data: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      if (_isDisposed || !mounted) return;
      setState(() {
        hasReachedMax = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  //set product list
  productList() async {
    if (_isDisposed || !mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      offset++;

      // Check connectivity first
      bool hasConnectivity = await Helper().checkConnectivity();

      if (hasConnectivity) {
        // Online mode - fetch fresh data and update cache
        try {
          print('Online mode - fetching fresh data');

          // Check last sync, if difference is 10 minutes then sync again
          String? lastSync = await System().getProductLastSync();
          final date2 = DateTime.now();
          bool needsSync = lastSync == null ||
              (date2.difference(DateTime.parse(lastSync)).inMinutes > 10);

          // Initialize/refresh data when online - but don't clear cache until sync is successful
          if (needsSync || offset == 1) {
            print('Syncing product data...');
            try {
              await Variations().refresh();
              await System().insertProductLastSyncDateTimeNow();
              print('Sync successful - cache updated');
            } catch (syncError) {
              print('Sync failed, keeping existing cache: $syncError');
              // Don't clear cache, continue with existing data
            }
          }

          findSellingPriceGroupId(selectedLocationId);

          // Get products from database (which may have fresh data or cached data)
          await Variations()
              .get(
              brandId: brandId,
              categoryId: categoryId,
              subCategoryId: subCategoryId,
              inStock: inStock,
              locationId: selectedLocationId,
              searchTerm: searchController.text,
              offset: offset,
              byAlphabets: byAlphabets,
              byPrice: byPrice)
              .then((element) {
            if (element.isEmpty && offset > 1) {
              setState(() {
                hasReachedMax = true;
              });
              return;
            }

            element.forEach((product) {
              var price;
              if (product['selling_price_group'] != null) {
                jsonDecode(product['selling_price_group']).forEach((element) {
                  if (element['key'] == sellingPriceGroupId) {
                    price = double.parse(element['value'].toString());
                  }
                });
              }
              if (_isDisposed || !mounted) return;
              setState(() {
                products.add(ProductModel().product(product, price));
              });
            });

            if (element.length < 10) { // Less than expected page size
              setState(() {
                hasReachedMax = true;
              });
            }
          });

          if (_isDisposed || !mounted) return;
          setState(() {
            isLoading = false;
          });

        } catch (networkError) {
          print('Network error, falling back to offline mode: $networkError');
          // If online mode fails, fallback to cached products
          await _loadProductsFromCache();
        }
      } else {
        print('No connectivity detected - using offline mode');
        // Load from cache when offline
        await _loadProductsFromCache();
      }

    } catch (e) {
      print('Error loading products: $e');
      if (_isDisposed || !mounted) return;
      setState(() {
        isLoading = false;
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  categoryList() async {
    List categories = await System().getCategories();

    _categoryMenuItems.add(
      DropdownMenuItem(
        child: Text(AppLocalizations.of(context).translate('select_category')),
        value: 0,
      ),
    );

    for (var category in categories) {
      _categoryMenuItems.add(
        DropdownMenuItem(
          child: Text(category['name']),
          value: category['id'],
        ),
      );
    }
  }

  subCategoryList(parentId) async {
    List subCategories = await System().getSubCategories(parentId);
    _subCategoryMenuItems = [];
    _subCategoryMenuItems.add(
      DropdownMenuItem(
        child:
        Text(AppLocalizations.of(context).translate('select_sub_category')),
        value: 0,
      ),
    );
    subCategories.forEach((element) {
      _subCategoryMenuItems.add(
        DropdownMenuItem(
          child: Text(jsonDecode(element['value'])['name']),
          value: jsonDecode(element['value'])['id'],
        ),
      );
    });
  }

  brandList() async {
    List brands = await System().getBrands();

    _brandsMenuItems.add(
      DropdownMenuItem(
        child: Text(AppLocalizations.of(context).translate('select_brand')),
        value: 0,
      ),
    );

    for (var brand in brands) {
      _brandsMenuItems.add(
        DropdownMenuItem(
          child: Text(brand['name']),
          value: brand['id'],
        ),
      );
    }
  }

  priceGroupList() async {
    setState(() {
      _priceGroupMenuItems = [];

      // Always add the false option
      _priceGroupMenuItems.add(
        DropdownMenuItem(
          child: Text(AppLocalizations.of(context)
              .translate('no_price_group_selected')),
          value: false,
        ),
      );

      // Check if current location has a price group
      bool hasPriceGroup = locationListMap.any((element) =>
      element['id'] == selectedLocationId &&
          element['selling_price_group_id'] != null);

      // Only add true option if location has price group
      if (hasPriceGroup) {
        _priceGroupMenuItems.add(
          DropdownMenuItem(
            child: Text(AppLocalizations.of(context)
                .translate('default_price_group')),
            value: true,
          ),
        );
      }

      // Update usePriceGroup to match available options
      usePriceGroup = hasPriceGroup;
    });
  }

  Future<String> getCartItemCount({isCompleted, sellId}) async {
    var counts =
    await Sell().cartItemCount(isCompleted: isCompleted, sellId: sellId);
    if (!_isDisposed && mounted) {
      setState(() {
        cartCount = int.parse(counts);
      });
    }
    return counts;
  }

  double findAspectRatio(double width) {
    //Logic for aspect ratio of grid view
    return (width / 2 - MySize.size24!) / ((width / 2 - MySize.size24!) + 60);
  }

// Method for auto-refresh functionality
  Future<void> _autoRefresh() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      if (products.isNotEmpty) {
        products = [];
        offset = 0;
      }
    });

    await productList();
  }

  @override
  Widget build(BuildContext context) {
    themeData = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        endDrawer: _filterDrawer(),
        appBar: AppBar(
          elevation: 0,
          title: Text(
            AppLocalizations.of(context).translate('products'),
            style: AppTheme.getTextStyle(
                themeData.textTheme.headline6, fontWeight: 600),
          ),
          leading: null,
          actions: <Widget>[
            IconButton(
              icon: isLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(Icons.sync),
              onPressed: isLoading ? null : syncProducts,
              tooltip: AppLocalizations.of(context).translate('sync_products'),
            ),
            locations(),
            badges.Badge(
              badgeStyle: BadgeStyle(badgeColor: Colors.red),
              position: badges.BadgePosition.topStart(start: 5.0, top: 5.0),
              badgeContent: FutureBuilder(
                  future: (argument != null && argument!['sellId'] != null)
                      ? getCartItemCount(sellId: argument!['sellId'])
                      : getCartItemCount(isCompleted: 0),
                  builder: (context, AsyncSnapshot<String> snapshot) {
                    return Center(
                      child: Text(
                          snapshot.hasData ? '${snapshot.data}' : "0",
                          style: TextStyle(color: Colors.white)),
                    );
                  }),
              child: IconButton(
                  icon: Icon(IconBroken.Buy,
                      size: 44, color: Color(0xff4c53a5)),
                  onPressed: () {
                    if (argument != null) {
                      Navigator.pushReplacementNamed(context, '/cart',
                          arguments: Helper().argument(
                              locId: argument!['locationId'],
                              sellId: argument!['sellId']));
                    } else if (selectedLocationId != 0 && cartCount > 0) {
                      Navigator.pushNamed(
                        context,
                        '/cart',
                        arguments:
                        Helper().argument(locId: selectedLocationId),
                      );
                    } else if (cartCount == 0) {
                      Fluttertoast.showToast(
                          msg: AppLocalizations.of(context)
                              .translate('no_items_added_to_cart'));
                    }
                  }),
            )
          ],
        ),
        body: isLoading && products.isEmpty
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _handleRefresh,
          child: Stack(
            children: [
              CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  if (selectedLocationId != 0)
                    SliverToBoxAdapter(child: filter(_scaffoldKey)),
                  selectedLocationId == 0
                      ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on),
                          Text(AppLocalizations.of(context)
                              .translate(
                              'please_set_a_location')),
                        ],
                      ),
                    ),
                  )
                      : products.isEmpty && !isLoading
                      ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(height: 10),
                          Text(AppLocalizations.of(context)
                              .translate(
                              'no_products_found')),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _handleRefresh,
                            child: Text(
                                AppLocalizations.of(context)
                                    .translate('refresh')),
                          ),
                        ],
                      ),
                    ),
                  )
                      : gridView
                      ? SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        return InkWell(
                          onTap: () async {
                            onTapProduct(index);
                          },
                          child: _ProductGridWidget(
                            name: products[index]
                            ['display_name'],
                            image: products[index]
                            ['product_image_url'],
                            qtyAvailable: (products[index]
                            ['enable_stock'] !=
                                0)
                                ? products[index]
                            ['stock_available']
                                .toString()
                                : '-',
                            price: double.parse(
                                products[index]
                                ['unit_price']
                                    .toString()),
                            symbol: symbol,
                          ),
                        );
                      },
                      childCount: products.length,
                    ),
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: MySize.size16!,
                      crossAxisSpacing: MySize.size16!,
                      childAspectRatio: findAspectRatio(
                          MediaQuery.of(context)
                              .size
                              .width),
                    ),
                  )
                      : SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        return InkWell(
                          onTap: () async {
                            onTapProduct(index);
                          },
                          child: _ProductListWidget(
                            name: products[index]
                            ['display_name'],
                            image: products[index]
                            ['product_image_url'],
                            qtyAvailable: (products[index]
                            ['enable_stock'] !=
                                0)
                                ? products[index]
                            ['stock_available']
                                .toString()
                                : '-',
                            price: double.parse(
                                products[index]
                                ['unit_price']
                                    .toString()),
                            symbol: symbol,
                          ),
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
                  if (isLoading && products.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
              if (_isRefreshing)
                Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterDrawer() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: EdgeInsets.only(bottom: MySize.size14!),
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding:
              EdgeInsets.only(top: MySize.size24!, bottom: MySize.size24!),
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  AppLocalizations.of(context).translate('sort'),
                  style: AppTheme.getTextStyle(themeData.textTheme.subtitle1,
                      fontWeight: 700, color: themeData.colorScheme.primary),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        setState(() {
                          if (byAlphabets == null) {
                            byAlphabets = 0;
                          } else if (byAlphabets == 0) {
                            byAlphabets = 1;
                          } else {
                            byAlphabets = null;
                          }
                        });
                        products = [];
                        offset = 0;
                        productList();
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: MySize.size16!),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.all(Radius.circular(MySize.size16!)),
                          boxShadow: [
                            BoxShadow(
                              color: themeData.cardTheme.shadowColor!
                                  .withAlpha(48),
                              blurRadius: (byAlphabets != null) ? 5 : 0,
                              offset: (byAlphabets != null)
                                  ? Offset(3, 3)
                                  : Offset(0, 0),
                            )
                          ],
                          // : null,
                        ),
                        padding: EdgeInsets.all(MySize.size12!),
                        child: Row(
                          children: [
                            Text(
                              "A",
                              style: AppTheme.getTextStyle(
                                  themeData.textTheme.subtitle1,
                                  fontWeight: 700,
                                  color: (byAlphabets != null)
                                      ? themeData.colorScheme.primary
                                      : Colors.grey),
                            ),
                            Icon(
                              (byAlphabets == 1)
                                  ? MdiIcons.arrowLeftBold
                                  : MdiIcons.arrowRightBold,
                              color: (byAlphabets != null)
                                  ? themeData.colorScheme.primary
                                  : Colors.grey,
                              size: 22,
                            ),
                            Text(
                              "Z",
                              style: AppTheme.getTextStyle(
                                  themeData.textTheme.subtitle1,
                                  fontWeight: 700,
                                  color: (byAlphabets != null)
                                      ? themeData.colorScheme.primary
                                      : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        setState(() {
                          if (byPrice == null) {
                            byPrice = 0;
                          } else if (byPrice == 0) {
                            byPrice = 1;
                          } else {
                            byPrice = null;
                          }
                        });
                        products = [];
                        offset = 0;
                        productList();
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: MySize.size16!),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.all(Radius.circular(MySize.size16!)),
                          boxShadow: [
                            BoxShadow(
                              color: themeData.cardTheme.shadowColor!
                                  .withAlpha(48),
                              blurRadius: (byPrice != null) ? 5 : 0,
                              offset: (byPrice != null)
                                  ? Offset(3, 3)
                                  : Offset(0, 0),
                            )
                          ],
                          // : null,
                        ),
                        padding: EdgeInsets.all(MySize.size12!),
                        child: Row(
                          children: [
                            Text(
                              AppLocalizations.of(context).translate('price'),
                              style: AppTheme.getTextStyle(
                                  themeData.textTheme.subtitle1,
                                  fontWeight: 700,
                                  color: (byPrice != null)
                                      ? themeData.colorScheme.primary
                                      : Colors.grey),
                            ),
                            Icon(
                              (byPrice == 1)
                                  ? MdiIcons.arrowDownBold
                                  : MdiIcons.arrowUpBold,
                              color: (byPrice != null)
                                  ? themeData.colorScheme.primary
                                  : Colors.grey,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(),
              ],
            ),
            Container(
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  AppLocalizations.of(context).translate('filter'),
                  style: AppTheme.getTextStyle(themeData.textTheme.subtitle1,
                      fontWeight: 700, color: themeData.colorScheme.primary),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                    padding: EdgeInsets.only(
                        left: MySize.size16!, right: MySize.size16!),
                    child: CheckboxListTile(
                      title: Text(
                          AppLocalizations.of(context).translate('in_stock')),
                      controlAffinity: ListTileControlAffinity.leading,
                      value: inStock,
                      onChanged: (newValue) {
                        setState(() {
                          inStock = newValue!;
                        });
                        products = [];
                        offset = 0;
                        productList();
                      },
                    )),
                Divider(),
                Container(
                  padding: EdgeInsets.only(
                      left: MySize.size16!,
                      right: MySize.size16!,
                      top: MySize.size16!),
                  child: Text(
                    AppLocalizations.of(context).translate('categories'),
                    style: AppTheme.getTextStyle(themeData.textTheme.bodyText1,
                        fontWeight: 600, letterSpacing: 0),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                      left: MySize.size16!,
                      right: MySize.size16!,
                      top: MySize.size8!),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: Icon(
                          Icons.arrow_drop_down,
                        ),
                        value: categoryId,
                        items: _categoryMenuItems,
                        onChanged: (int? newValue) {
                          setState(() {
                            subCategoryId = 0;
                            categoryId = newValue!;
                            subCategoryList(categoryId);
                          });

                          products = [];
                          offset = 0;
                          productList();
                        }),
                  ),
                ),
                Divider(),
                Container(
                  padding: EdgeInsets.only(
                      left: MySize.size16!,
                      right: MySize.size16!,
                      top: MySize.size16!),
                  child: Text(
                    AppLocalizations.of(context).translate('sub_categories'),
                    style: AppTheme.getTextStyle(themeData.textTheme.bodyText1,
                        fontWeight: 600, letterSpacing: 0),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                      left: MySize.size16!,
                      right: MySize.size16!,
                      top: MySize.size8!),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: Icon(
                          Icons.arrow_drop_down,
                        ),
                        value: subCategoryId,
                        items: _subCategoryMenuItems,
                        onChanged: (int? newValue) {
                          setState(() {
                            subCategoryId = newValue!;
                          });

                          products = [];
                          offset = 0;
                          productList();
                        }),
                  ),
                ),
                Divider(),
                Container(
                  padding: EdgeInsets.only(
                      left: MySize.size16!,
                      right: MySize.size16!,
                      top: MySize.size16!),
                  child: Text(
                    AppLocalizations.of(context).translate('brands'),
                    style: AppTheme.getTextStyle(themeData.textTheme.bodyText1,
                        fontWeight: 600, letterSpacing: 0),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                      left: MySize.size16!, right: MySize.size16!, top: 0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: Icon(
                          Icons.arrow_drop_down,
                        ),
                        value: brandId,
                        items: _brandsMenuItems,
                        onChanged: (int? newValue) {
                          setState(() {
                            brandId = newValue!;
                          });
                          products = [];
                          offset = 0;
                          productList();
                        }),
                  ),
                ),
                Divider()
              ],
            ),
            Container(
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  AppLocalizations.of(context).translate('group_prices'),
                  style: AppTheme.getTextStyle(themeData.textTheme.subtitle1,
                      fontWeight: 700, color: themeData.colorScheme.primary),
                ),
              ),
            ),
            Container(
                padding: EdgeInsets.only(
                    left: MySize.size16!, right: MySize.size16!, top: 0),
                child: DropdownButton<bool>(
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: Icon(Icons.arrow_drop_down),
                  value: usePriceGroup,
                  items: _priceGroupMenuItems,
                  onChanged: (bool? newValue) async {
                    if (newValue == null) return;

                    // Show confirmation dialog if changing from true to false
                    if (usePriceGroup && !newValue) {
                      await _showCartResetDialogForPriceGroup();
                      if (!changePriceGroup) return;
                    }

                    setState(() {
                      usePriceGroup = newValue;
                      if (changePriceGroup) {
                        // Reset cart items if price group changed
                        Sell().resetCart();
                        // Reset filters
                        brandId = 0;
                        categoryId = 0;
                        searchController.clear();
                        inStock = true;
                        cartCount = 0;
                        products = [];
                        offset = 0;
                        productList();
                      }
                    });
                  },
                )
            )
          ],
        ),
      ),
    );
  }

  Widget filter(_scaffoldKey) {
    return Padding(
      padding: EdgeInsets.all(MySize.size16!),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Form(
              key: _formKey,
              child: TextFormField(
                  style: AppTheme.getTextStyle(themeData.textTheme.subtitle2,
                      letterSpacing: 0, fontWeight: 500),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('search'),
                    hintStyle: AppTheme.getTextStyle(
                        themeData.textTheme.subtitle2,
                        letterSpacing: 0,
                        fontWeight: 500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(MySize.size16!),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(MySize.size16!),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(MySize.size16!),
                        ),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Color(0xffedecf2),
                    prefixIcon: IconButton(
                      icon: Icon(
                        MdiIcons.magnify,
                        size: MySize.size22,
                        color:
                        themeData.colorScheme.onBackground.withAlpha(150),
                      ),
                      onPressed: () {},
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.only(right: MySize.size16!),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  controller: searchController,
                  onEditingComplete: () {
                    products = [];
                    offset = 0;
                    productList();
                  }),
            ),
          ),
          SizedBox(
            width: 10,
          ),
          InkWell(
            onTap: () async {
              var barcode = await Helper().barcodeScan();
              await getScannedProduct(barcode);
            },
            child: Container(
              margin: EdgeInsets.only(left: MySize.size16!),
              decoration: BoxDecoration(
                color: Color(0xffedecf2),
                borderRadius: BorderRadius.all(Radius.circular(MySize.size16!)),
                boxShadow: [
                  BoxShadow(
                    color: themeData.cardTheme.shadowColor!.withAlpha(48),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  )
                ],
              ),
              padding: EdgeInsets.all(MySize.size12!),
              child: Icon(
                MdiIcons.barcode,
                color: themeData.colorScheme.primary,
                size: 22,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              _scaffoldKey.currentState.openEndDrawer();
            },
            child: Container(
              margin: EdgeInsets.only(left: MySize.size16!),
              decoration: BoxDecoration(
                color: Color(0xffedecf2),
                borderRadius: BorderRadius.all(Radius.circular(MySize.size16!)),
                boxShadow: [
                  BoxShadow(
                    color: themeData.cardTheme.shadowColor!.withAlpha(48),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  )
                ],
              ),
              padding: EdgeInsets.all(MySize.size12!),
              child: Icon(
                MdiIcons.tune,
                color: themeData.colorScheme.primary,
                size: 22,
              ),
            ),
          ),
          InkWell(
            onTap: () async {
              setState(() {
                gridView = !gridView;
              });
            },
            child: Container(
              margin: EdgeInsets.only(left: MySize.size16!),
              decoration: BoxDecoration(
                color: Color(0xffedecf2),
                borderRadius: BorderRadius.all(Radius.circular(MySize.size16!)),
                boxShadow: [
                  BoxShadow(
                    color: themeData.cardTheme.shadowColor!.withAlpha(48),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  )
                ],
              ),
              padding: EdgeInsets.all(MySize.size12!),
              child: Icon(
                (gridView) ? MdiIcons.viewList : MdiIcons.viewGrid,
                color: themeData.colorScheme.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //add product to cart after scanning barcode
  getScannedProduct(String barcode) async {
    await Variations()
        .get(
        locationId: selectedLocationId,
        barcode: barcode,
        offset: 0,
        searchTerm: searchController.text)
        .then((value) async {
      if (value.length > 0) {
        var price;
        var product;
        if (value[0]['selling_price_group'] != null) {
          jsonDecode(value[0]['selling_price_group']).forEach((element) {
            if (element['key'] == sellingPriceGroupId) {
              price = element['value'];
            }
          });
        }
        setState(() {
          product = ProductModel().product(value[0], price);
        });
        if (product != null && product['stock_available'] > 0) {
          Fluttertoast.showToast(
              msg: AppLocalizations.of(context).translate('added_to_cart'));
          await Sell().addToCart(
              product, argument != null ? argument!['sellId'] : null);
          if (argument != null) {
            selectedLocationId = argument!['locationId'];
          }
        } else {
          Fluttertoast.showToast(
              msg:
              "${AppLocalizations.of(context).translate("out_of_stock")}");
        }
      } else {
        Fluttertoast.showToast(
            msg:
            "${AppLocalizations.of(context).translate("no_product_found")}");
      }
    });
  }

  Widget _productsList() {
    return (products.length == 0)
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty),
          Text(AppLocalizations.of(context)
              .translate('no_products_found')),
        ],
      ),
    )
        : Container(
      child: (gridView)
          ? GridView.builder(
        padding: EdgeInsets.only(
            bottom: MySize.size16!,
            left: MySize.size16!,
            right: MySize.size16!),
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemCount: products.length,
        gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: MySize.size16!,
          crossAxisSpacing: MySize.size16!,
          childAspectRatio:
          findAspectRatio(MediaQuery.of(context).size.width),
        ),
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () async {
              onTapProduct(index);
            },
            child: _ProductGridWidget(
              name: products[index]['display_name'],
              image: products[index]['product_image_url'],
              qtyAvailable: (products[index]['enable_stock'] != 0)
                  ? products[index]['stock_available'].toString()
                  : '-',
              price: double.parse(
                  products[index]['unit_price'].toString()),
              symbol: symbol,
            ),
          );
        },
      )
          : ListView.separated(
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () async {
              onTapProduct(index);
            },
            child: _ProductListWidget(
              name: products[index]['display_name'],
              image: products[index]['product_image_url'],
              qtyAvailable: (products[index]['enable_stock'] != 0)
                  ? products[index]['stock_available'].toString()
                  : '-',
              price: double.parse(
                  products[index]['unit_price'].toString()),
              symbol: symbol,
            ),
          );
        },
        separatorBuilder: (BuildContext context, int index) =>
            Container(
              height: 10,
              color: Colors.white,
            ),
      ),
    );
  }

  //onTap product
  onTapProduct(int index) async {

    // Check stock before attempting to add
    if (products[index]['enable_stock'] != 0 && products[index]['stock_available'] <= 0) {
      Fluttertoast.showToast(
          msg: "${AppLocalizations.of(context).translate("out_of_stock")}");
      return;
    }

    try {
      bool added = await Sell().addToCart(
          products[index],
          argument != null ? argument!['sellId'] : null
      );

      if (added) {
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context).translate('added_to_cart'));

        // Update cart count
        await getCartItemCount(
            isCompleted: 0,
            sellId: argument != null ? argument!['sellId'] : null
        );

        if (argument != null) {
          selectedLocationId = argument!['locationId'];
        }
      } else {
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context).translate('item_already_in_cart'));
      }
    } catch (e) {
      if (e.toString().contains('Insufficient stock')) {
        Fluttertoast.showToast(
            msg: "${AppLocalizations.of(context).translate("out_of_stock")}");
      } else {
        Fluttertoast.showToast(
            msg: 'Error adding item to cart');
      }
    }
  }

  setLocationMap() async {
    await System().get('location').then((value) async {
      value.forEach((element) {
        if (element['is_active'].toString() == '1') {
          setState(() {
            locationListMap.add({
              'id': element['id'],
              'name': element['name'],
              'selling_price_group_id': element['selling_price_group_id']
            });
          });
        }
      });
      await priceGroupList();
    });
  }

  Future<void> setDefaultLocation(defaultLocation) async {
    if (defaultLocation != 0) {
      setState(() {
        selectedLocationId = defaultLocation;
      });
    } else if (locationListMap.length == 2) {
      setState(() {
        selectedLocationId = locationListMap[1]['id'] as int;
      });
    }
  }

  Widget locations() {
    return DropdownButtonHideUnderline(
      child: DropdownButton(
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
          ),
          value: selectedLocationId,
          items: locationListMap.map<DropdownMenuItem<int>>((Map value) {
            return DropdownMenuItem<int>(
                value: value['id'],
                child: SizedBox(
                  width: MySize.screenWidth! * 0.4,
                  child: Text('${value['name']}',
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(fontSize: 15)),
                ));
          }).toList(),
          onTap: () {
            if (locationListMap.length <= 2) {
              canChangeLocation = false;
            }
          },
          onChanged: (int? newValue) async {
            // show a confirmation if there location is changed.
            if (canChangeLocation) {
              if (selectedLocationId == newValue) {
                changeLocation = false;
              } else if (selectedLocationId != 0) {
                await _showCartResetDialogForLocation();
                await priceGroupList();
              } else {
                changeLocation = true;
                await priceGroupList();
              }
              setState(() {
                if (changeLocation) {
                  //reset cart items
                  Sell().resetCart();
                  selectedLocationId = newValue!;
                  //reset all filters & search
                  brandId = 0;
                  categoryId = 0;
                  searchController.clear();
                  inStock = true;
                  cartCount = 0;

                  products = [];
                  offset = 0;
                  productList();
                }
              });
            } else {
              Fluttertoast.showToast(
                  msg: AppLocalizations.of(context)
                      .translate('cannot_change_location'));
            }
          }),
    );
  }

  Future<void> _showCartResetDialogForLocation() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
          Text(AppLocalizations.of(context).translate('change_location')),
          content: Text(AppLocalizations.of(context)
              .translate('all_items_in_cart_will_be_remove')),
          actions: [
            TextButton(
                onPressed: () {
                  changeLocation = false;
                  Navigator.of(context).pop();
                },
                child: Text(AppLocalizations.of(context).translate('no'))),
            TextButton(
                onPressed: () {
                  changeLocation = true;
                  Navigator.of(context).pop();
                },
                child: Text(AppLocalizations.of(context).translate('yes')))
          ],
        );
      },
    );
  }

  Future<void> _showCartResetDialogForPriceGroup() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)
              .translate('change_selling_price_group')),
          content: Text(AppLocalizations.of(context)
              .translate('all_items_in_cart_will_be_remove')),
          actions: [
            TextButton(
                onPressed: () {
                  changePriceGroup = false;
                  Navigator.of(context).pop();
                },
                child: Text(AppLocalizations.of(context).translate('no'))),
            TextButton(
                onPressed: () {
                  changePriceGroup = true;
                  Navigator.of(context).pop();
                },
                child: Text(AppLocalizations.of(context).translate('yes')))
          ],
        );
      },
    );
  }
}

class _ProductGridWidget extends StatefulWidget {
  final String? name, image, symbol;
  final String? qtyAvailable;
  final double? price;

  const _ProductGridWidget(
      {Key? key,
        @required this.name,
        @required this.image,
        @required this.qtyAvailable,
        @required this.price,
        @required this.symbol})
      : super(key: key);

  @override
  _ProductGridWidgetState createState() => _ProductGridWidgetState();
}

class _ProductGridWidgetState extends State<_ProductGridWidget> {
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);

  @override
  Widget build(BuildContext context) {
    String key = Generator.randomString(10);
    themeData = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Color(0xffedecf2),
        borderRadius: BorderRadius.all(Radius.circular(MySize.size8!)),
        boxShadow: [
          BoxShadow(
            color: themeData.cardTheme.shadowColor!.withAlpha(12),
            blurRadius: 4,
            spreadRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(MySize.size2!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          Stack(
            children: <Widget>[
              Hero(
                tag: key,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(MySize.size8!),
                      topRight: Radius.circular(MySize.size8!)),
                  child: CachedNetworkImage(
                      width: MediaQuery.of(context).size.width,
                      height: MySize.size140,
                      fit: BoxFit.fitHeight,
                      errorWidget: (context, url, error) =>
                          Image.asset('assets/images/default_product.png'),
                      placeholder: (context, url) =>
                          Image.asset('assets/images/default_product.png'),
                      imageUrl: widget.image ?? ''),
                ),
              ),
            ],
          ),
          Container(
            width: MediaQuery.of(context).size.width,
            padding: EdgeInsets.only(left: MySize.size2!, right: MySize.size2!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.name!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: AppTheme.getTextStyle(themeData.textTheme.subtitle2,
                        fontWeight: 500, letterSpacing: 0)),
                Container(
                  margin: EdgeInsets.only(top: MySize.size4!),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        Helper().formatCurrency(widget.price) + widget.symbol!,
                        style: AppTheme.getTextStyle(
                            themeData.textTheme.bodyText2,
                            fontWeight: 700,
                            letterSpacing: 0),
                      ),
                      Container(
                        decoration: BoxDecoration(
                            color: themeData.colorScheme.primary,
                            borderRadius: BorderRadius.all(
                                Radius.circular(MySize.size4!))),
                        padding: EdgeInsets.only(
                            left: MySize.size6!,
                            right: MySize.size8!,
                            top: MySize.size2!,
                            bottom: MySize.getScaledSizeHeight(3.5)),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              MdiIcons.stocking,
                              color: themeData.colorScheme.onPrimary,
                              size: MySize.size12,
                            ),
                            Container(
                              margin: EdgeInsets.only(left: MySize.size4!),
                              child: (widget.qtyAvailable != '-')
                                  ? Text(
                                  Helper()
                                      .formatQuantity(widget.qtyAvailable),
                                  style: AppTheme.getTextStyle(
                                      themeData.textTheme.caption,
                                      fontSize: 11,
                                      color:
                                      themeData.colorScheme.onPrimary,
                                      fontWeight: 600))
                                  : Text('-'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductListWidget extends StatefulWidget {
  final String? name, image, symbol;
  final String? qtyAvailable;
  final double? price;

  const _ProductListWidget(
      {Key? key,
        @required this.name,
        @required this.image,
        @required this.qtyAvailable,
        @required this.price,
        @required this.symbol})
      : super(key: key);

  @override
  _ProductListWidgetState createState() => _ProductListWidgetState();
}

class _ProductListWidgetState extends State<_ProductListWidget> {
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);

  @override
  Widget build(BuildContext context) {
    themeData = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Color(0xffedecf2),
        borderRadius: BorderRadius.all(Radius.circular(MySize.size8!)),
        boxShadow: [
          BoxShadow(
            color: themeData.cardTheme.shadowColor!.withAlpha(12),
            blurRadius: 4,
            spreadRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(MySize.size8!),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(MySize.size30!),
          child: CachedNetworkImage(
              errorWidget: (context, url, error) =>
                  Image.asset('assets/images/default_product.png'),
              placeholder: (context, url) =>
                  Image.asset('assets/images/default_product.png'),
              imageUrl: widget.image ?? ''),
        ),
        title: Text(widget.name!,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: AppTheme.getTextStyle(themeData.textTheme.subtitle2,
                fontWeight: 500, letterSpacing: 0)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Text(
              Helper().formatCurrency(widget.price) + widget.symbol!,
              style: AppTheme.getTextStyle(themeData.textTheme.bodyText2,
                  fontWeight: 700, letterSpacing: 0),
            ),
            Container(
              width: MySize.size80,
              decoration: BoxDecoration(
                  color: themeData.colorScheme.primary,
                  borderRadius:
                  BorderRadius.all(Radius.circular(MySize.size4!))),
              padding: EdgeInsets.only(
                  left: MySize.size6!,
                  right: MySize.size8!,
                  top: MySize.size2!,
                  bottom: MySize.getScaledSizeHeight(3.5)),
              child: Row(
                children: <Widget>[
                  Icon(
                    MdiIcons.stocking,
                    color: themeData.colorScheme.onPrimary,
                    size: MySize.size12,
                  ),
                  Container(
                    margin: EdgeInsets.only(left: MySize.size4!),
                    child: (widget.qtyAvailable != '-')
                        ? Text(Helper().formatQuantity(widget.qtyAvailable),
                        style: AppTheme.getTextStyle(
                            themeData.textTheme.caption,
                            fontSize: 11,
                            color: themeData.colorScheme.onPrimary,
                            fontWeight: 600))
                        : Text('-'),
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