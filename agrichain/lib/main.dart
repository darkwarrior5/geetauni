import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/my_crops_screen.dart';
import 'screens/loans_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/add_crop_screen.dart';
import 'screens/downloads_screen.dart';
import 'providers/app_state.dart';
import 'config/app_initializer.dart';
import 'models/firestore_models.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const AgriChainApp());
}

class AgriChainApp extends StatefulWidget {
  const AgriChainApp({super.key});

  @override
  State<AgriChainApp> createState() => _AgriChainAppState();
}

class _AgriChainAppState extends State<AgriChainApp> {
  bool _isInitialized = false;
  bool _initializationFailed = false;
  String _errorMessage = '';
  bool _isFirstTime = true;
  bool _checkingFirstTime = true;
  final AppInitializer _appInitializer = AppInitializer();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if this is the first time opening the app
      await _checkFirstTimeUser();
      
      final success = await _appInitializer.initialize();
      setState(() {
        _isInitialized = success;
        _initializationFailed = !success;
        _checkingFirstTime = false;
        if (!success) {
          final results = _appInitializer.initializationResults;
          _errorMessage = results['error']?.toString() ?? 'Unknown initialization error';
        }
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _initializationFailed = true;
        _checkingFirstTime = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    setState(() {
      _isFirstTime = !hasSeenOnboarding;
    });
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    setState(() {
      _isFirstTime = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final appState = AppState();
          // Initialize AppState after creation to trigger mock data initialization
          appState.initialize();
          return appState;
        }),
      ],
      child: MaterialApp(
        title: 'AgriChain',
        theme: AppTheme.lightTheme,
        home: _buildHome(),
        debugShowCheckedModeBanner: false,
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/add-crop':
        return MaterialPageRoute(
          builder: (context) => const AddCropScreen(),
          settings: settings,
        );
      default:
        return null;
    }
  }

  Widget _buildHome() {
    if (_initializationFailed) {
      return _buildErrorScreen();
    }
    
    if (!_isInitialized || _checkingFirstTime) {
      return _buildLoadingScreen();
    }
    
    // Show onboarding for first-time users
    if (_isFirstTime) {
      return OnboardingScreen(
        onComplete: _markOnboardingComplete,
      );
    }
    
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('🔄 StreamBuilder rebuild - Connection: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, User: ${snapshot.data?.uid}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ Waiting for auth state...');
          return _buildLoadingScreen();
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          debugPrint('✅ User authenticated: ${snapshot.data!.uid}');
          // User is signed in, load their data and show main screen
          final appState = Provider.of<AppState>(context, listen: false);
          
          // Only load user data if not already loaded for this user
          if (appState.currentUser?.id != snapshot.data!.uid) {
            debugPrint('📥 Loading user data for: ${snapshot.data!.uid}');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              appState.loadUserData(snapshot.data!.uid);
            });
          } else {
            debugPrint('✓ User data already loaded');
          }
          return const MainScreen();
        } else {
          debugPrint('🔓 No user authenticated - showing LoginScreen');
          // User is not signed in, show login screen
          return const LoginScreen();
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF4CAF50),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.agriculture,
                  size: 60,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 40),
              
              // App Name
              const Text(
                'AgriChain',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              
              // Tagline
              const Text(
                'Empowering Agriculture with Blockchain',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 60),
              
              // Loading Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 20),
              
              // Loading Text
              const Text(
                'Initializing application...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD32F2F),
              Color(0xFFE57373),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Error Title
                const Text(
                  'Initialization Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Error Message
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Retry Button
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInitialized = false;
                      _initializationFailed = false;
                      _errorMessage = '';
                    });
                    _initializeApp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFD32F2F),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Farmer/Seller screens
  final List<Widget> _farmerScreens = [
    const HomeScreen(),
    const MyCropsScreen(),
    const LoansScreen(),
    const MarketplaceScreen(),
    const DownloadsScreen(),
    const ProfileScreen(),
  ];

  // Buyer screens
  final List<Widget> _buyerScreens = [
    const MarketplaceScreen(),
    const WalletScreen(),
    const ProfileScreen(),
    const LoansScreen(),
    const DownloadsScreen(),
    const AnalyticsScreen(),
  ];

  // Farmer/Seller navigation items
  final List<BottomNavigationBarItem> _farmerNavItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.agriculture_outlined),
      activeIcon: Icon(Icons.agriculture),
      label: 'My Crops',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_outlined),
      activeIcon: Icon(Icons.account_balance),
      label: 'Loans',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.shopping_cart_outlined),
      activeIcon: Icon(Icons.shopping_cart),
      label: 'Marketplace',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.download_outlined),
      activeIcon: Icon(Icons.download),
      label: 'Downloads',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  // Buyer navigation items
  final List<BottomNavigationBarItem> _buyerNavItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.store_outlined),
      activeIcon: Icon(Icons.store),
      label: 'Market',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet_outlined),
      activeIcon: Icon(Icons.account_balance_wallet),
      label: 'Wallet',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_outlined),
      activeIcon: Icon(Icons.account_balance),
      label: 'Loans',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.download_outlined),
      activeIcon: Icon(Icons.download),
      label: 'Downloads',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.analytics_outlined),
      activeIcon: Icon(Icons.analytics),
      label: 'Analytics',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final user = appState.currentUser;
        
        // Show loading while user data is being loaded
        if (appState.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            ),
          );
        }
        
        // If no user data but Firebase user exists, redirect to login
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            ),
          );
        }

        final isBuyer = user.userType == UserType.buyer;
        final screens = isBuyer ? _buyerScreens : _farmerScreens;
        final navItems = isBuyer ? _buyerNavItems : _farmerNavItems;

        // Ensure current index is within bounds
        if (_currentIndex >= screens.length) {
          _currentIndex = 0;
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            title: Text(_getScreenTitle(isBuyer)),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  appState.clearUser();
                },
                tooltip: 'Logout',
              ),
            ],
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: screens[_currentIndex],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              items: navItems,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: AppTheme.primaryGreen,
              unselectedItemColor: AppTheme.grey,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  String _getScreenTitle(bool isBuyer) {
    if (isBuyer) {
      switch (_currentIndex) {
        case 0: return 'Marketplace';
        case 1: return 'Wallet';
        case 2: return 'Profile';
        case 3: return 'Loans';
        case 4: return 'Analytics';
        default: return 'AgriChain';
      }
    } else {
      switch (_currentIndex) {
        case 0: return 'Home';
        case 1: return 'My Crops';
        case 2: return 'Loans';
        case 3: return 'Marketplace';
        case 4: return 'Profile';
        default: return 'AgriChain';
      }
    }
  }
}
