import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_state.dart';
import '../models/firestore_models.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import '../screens/rating_screen.dart';
import '../screens/debug_sample_users_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/wallet_connection_screen.dart';
import '../screens/transaction_history_screen.dart';
import '../screens/mint_land_nft_screen.dart';
import '../screens/mint_crop_nft_screen.dart';
import '../config/app_config.dart';
import '../services/profile_service.dart';
import '../services/wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  bool _biometricEnabled = false;
  Map<String, dynamic>? _profileData;
  bool _isLoadingProfile = true;
  final ProfileService _profileService = ProfileService();
  final WalletService _walletService = WalletService();
  bool _isWalletConnected = false;
  String? _walletAddress;
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _checkWalletConnection();
  }

  Future<void> _loadProfileData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final userId = appState.currentUser?.id;
    
    if (userId != null) {
      try {
        final profileData = await _profileService.getUserProfile(userId);
        if (mounted) {
          setState(() {
            _profileData = profileData;
            _isLoadingProfile = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingProfile = false;
          });
        }
        debugPrint('Error loading profile data: $e');
      }
    } else {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _checkWalletConnection() async {
    try {
      final isConnected = WalletService.isConnected;
      if (isConnected) {
        final address = WalletService.connectedAddress;
        final balance = await WalletService.getWalletBalance();
        
        if (mounted) {
          setState(() {
            _isWalletConnected = true;
            _walletAddress = address;
            _walletBalance = balance;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking wallet connection: $e');
    }
  }

  Future<void> _connectWallet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WalletConnectionScreen(),
      ),
    );
    
    if (result == true) {
      await _checkWalletConnection();
    }
  }

  Future<void> _viewTransactionHistory() async {
    if (_isWalletConnected) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TransactionHistoryScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            CustomAppBar(
              title: 'Profile',
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editProfile(context),
                ),
              ],
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildProfileDetailsSection(),
              const SizedBox(height: 24),
              _buildWalletSection(),
              const SizedBox(height: 24),
              _buildMenuSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final user = appState.currentUser;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryGreen, AppTheme.accentGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'Guest User',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? 'No email provided',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user?.userType == UserType.farmer ? 'Verified Farmer' : 'Verified Buyer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildRatingSection(appState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileDetailsSection() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (_isLoadingProfile) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_profileData == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: AppTheme.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Profile Not Complete',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete your profile to unlock all features',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _editProfile(context),
                  child: const Text('Complete Profile'),
                ),
              ],
            ),
          );
        }

        // Parse profile data
        Map<String, dynamic> profileInfo = {};
        if (_profileData!['profileData'] is String) {
          try {
            profileInfo = Map<String, dynamic>.from(
              jsonDecode(_profileData!['profileData'])
            );
          } catch (e) {
            debugPrint('Error parsing profile data: $e');
          }
        } else if (_profileData!['profileData'] is Map) {
          profileInfo = Map<String, dynamic>.from(_profileData!['profileData']);
        }

        final userType = appState.currentUser?.userType;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Profile Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _editProfile(context),
                    child: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildProfileInfoGrid(profileInfo, userType),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoGrid(Map<String, dynamic> profileInfo, UserType? userType) {
    final List<Widget> infoCards = [];

    // Location Information
    if (profileInfo['address'] != null || profileInfo['city'] != null) {
      infoCards.add(_buildInfoCard(
        'Location',
        _buildLocationInfo(profileInfo),
        Icons.location_on_outlined,
        AppTheme.primaryGreen,
      ));
    }

    // User Type Specific Information
    if (userType == UserType.farmer) {
      infoCards.addAll(_buildFarmerSpecificCards(profileInfo));
    } else if (userType == UserType.buyer) {
      infoCards.addAll(_buildBuyerSpecificCards(profileInfo));
    }

    // Additional Information
    if (profileInfo['bio'] != null && profileInfo['bio'].toString().isNotEmpty) {
      infoCards.add(_buildInfoCard(
        'Bio',
        profileInfo['bio'].toString(),
        Icons.description_outlined,
        AppTheme.accentGreen,
      ));
    }

    if (profileInfo['experience'] != null && profileInfo['experience'].toString().isNotEmpty) {
      infoCards.add(_buildInfoCard(
        'Experience',
        '${profileInfo['experience']} years',
        Icons.work_outline,
        AppTheme.sunYellow,
      ));
    }

    return Column(
      children: [
        for (int i = 0; i < infoCards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < infoCards.length ? 12 : 0),
            child: Row(
              children: [
                Expanded(child: infoCards[i]),
                if (i + 1 < infoCards.length) ...[
                  const SizedBox(width: 12),
                  Expanded(child: infoCards[i + 1]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _buildLocationInfo(Map<String, dynamic> profileInfo) {
    final parts = <String>[];
    if (profileInfo['city'] != null) parts.add(profileInfo['city'].toString());
    if (profileInfo['state'] != null) parts.add(profileInfo['state'].toString());
    if (profileInfo['pincode'] != null) parts.add(profileInfo['pincode'].toString());
    return parts.join(', ');
  }

  List<Widget> _buildFarmerSpecificCards(Map<String, dynamic> profileInfo) {
    final List<Widget> cards = [];

    if (profileInfo['farmSize'] != null && profileInfo['farmSize'].toString().isNotEmpty) {
      cards.add(_buildInfoCard(
        'Farm Size',
        profileInfo['farmSize'].toString(),
        Icons.landscape_outlined,
        AppTheme.earthBrown,
      ));
    }

    if (profileInfo['crops'] != null) {
      String cropsText = '';
      if (profileInfo['crops'] is List) {
        final cropsList = List<String>.from(profileInfo['crops']);
        cropsText = cropsList.take(3).join(', ');
        if (cropsList.length > 3) {
          cropsText += ' +${cropsList.length - 3} more';
        }
      } else {
        cropsText = profileInfo['crops'].toString();
      }
      
      if (cropsText.isNotEmpty) {
        cards.add(_buildInfoCard(
          'Crops',
          cropsText,
          Icons.grass_outlined,
          AppTheme.primaryGreen,
        ));
      }
    }

    return cards;
  }

  List<Widget> _buildBuyerSpecificCards(Map<String, dynamic> profileInfo) {
    final List<Widget> cards = [];

    if (profileInfo['businessType'] != null && profileInfo['businessType'].toString().isNotEmpty) {
      cards.add(_buildInfoCard(
        'Business Type',
        profileInfo['businessType'].toString(),
        Icons.business_outlined,
        AppTheme.primaryGreen,
      ));
    }

    if (profileInfo['gstNumber'] != null && profileInfo['gstNumber'].toString().isNotEmpty) {
      cards.add(_buildInfoCard(
        'GST Number',
        profileInfo['gstNumber'].toString(),
        Icons.receipt_outlined,
        AppTheme.sunYellow,
      ));
    }

    if (profileInfo['services'] != null) {
      String servicesText = '';
      if (profileInfo['services'] is List) {
        final servicesList = List<String>.from(profileInfo['services']);
        servicesText = servicesList.take(2).join(', ');
        if (servicesList.length > 2) {
          servicesText += ' +${servicesList.length - 2} more';
        }
      } else {
        servicesText = profileInfo['services'].toString();
      }
      
      if (servicesText.isNotEmpty) {
        cards.add(_buildInfoCard(
          'Services',
          servicesText,
          Icons.handyman_outlined,
          AppTheme.accentGreen,
        ));
      }
    }

    return cards;
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(AppState appState) {
    // Default rating stats since FirestoreUser doesn't have rating properties yet
    final buyerStats = _createDefaultRatingStats();
    final sellerStats = _createDefaultRatingStats();
    
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showRatings(RatingType.buyer),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'As Buyer',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        buyerStats.averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '(${buyerStats.totalRatings})',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _showRatings(RatingType.seller),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'As Seller',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sellerStats.averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '(${sellerStats.totalRatings})',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletSection() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Wallet & Blockchain',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showWalletDetails(context),
                    child: const Text('View Details'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Traditional Wallet Balance
              Row(
                children: [
                  Expanded(
                    child: _buildWalletCard(
                      'INR Balance',
                      '₹${appState.currentUser?.walletBalance.toStringAsFixed(0) ?? '0'}',
                      Icons.currency_rupee,
                      AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildWalletCard(
                      'Crypto Balance',
                      '${_walletBalance.toStringAsFixed(4)} ETH',
                      Icons.currency_bitcoin,
                      AppTheme.sunYellow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Blockchain Wallet Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isWalletConnected 
                    ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isWalletConnected 
                      ? AppTheme.primaryGreen.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isWalletConnected ? Icons.check_circle : Icons.account_balance_wallet_outlined,
                          color: _isWalletConnected ? AppTheme.primaryGreen : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isWalletConnected ? 'Blockchain Wallet Connected' : 'Connect Blockchain Wallet',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isWalletConnected ? AppTheme.primaryGreen : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    if (_isWalletConnected && _walletAddress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Address: ${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addMoney(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Money'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _withdrawMoney(context),
                      icon: const Icon(Icons.remove),
                      label: const Text('Withdraw'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isWalletConnected ? _viewTransactionHistory : _connectWallet,
                      icon: Icon(_isWalletConnected ? Icons.history : Icons.link),
                      label: Text(_isWalletConnected ? 'Transactions' : 'Connect Wallet'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isWalletConnected ? AppTheme.primaryGreen : Colors.blue,
                      ),
                    ),
                  ),
                  if (_isWalletConnected) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await WalletService.disconnectWallet(userId: appState.currentUser?.id);
                          await _checkWalletConnection();
                        },
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWalletCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _buildMenuGroup(
          'Account',
          [
            _MenuItemData(
              icon: Icons.person_outline,
              title: 'Personal Information',
              subtitle: 'Update your profile details',
              onTap: () => _editProfile(context),
            ),
            _MenuItemData(
              icon: Icons.star_outline,
              title: 'Ratings & Reviews',
              subtitle: 'View your ratings and feedback',
              onTap: () => _showAllRatings(context),
            ),
            _MenuItemData(
              icon: Icons.security,
              title: 'Security',
              subtitle: 'Password, 2FA, biometric',
              onTap: () => _showSecuritySettings(context),
            ),
            _MenuItemData(
              icon: Icons.verified_user,
              title: 'Verification',
              subtitle: 'KYC and document verification',
              onTap: () => _showVerificationStatus(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildMenuGroup(
          'Blockchain & NFTs',
          [
            _MenuItemData(
              icon: Icons.landscape,
              title: 'Mint Land NFT',
              subtitle: 'Tokenize your land property',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MintLandNFTScreen()),
              ),
            ),
            _MenuItemData(
              icon: Icons.agriculture,
              title: 'Mint Crop NFT',
              subtitle: 'Tokenize your crop harvest',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MintCropNFTScreen()),
              ),
            ),
            _MenuItemData(
              icon: Icons.account_balance_wallet,
              title: 'Blockchain Wallet',
              subtitle: _isWalletConnected ? 'Connected' : 'Not connected',
              onTap: _isWalletConnected ? _viewTransactionHistory : _connectWallet,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildMenuGroup(
          'Preferences',
          [
            _MenuItemData(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
              onTap: () => _showNotificationSettings(context),
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
                activeThumbColor: AppTheme.primaryGreen,
              ),
            ),
            _MenuItemData(
              icon: Icons.language,
              title: 'Language',
              subtitle: _selectedLanguage,
              onTap: () => _showLanguageSettings(context),
            ),
            _MenuItemData(
              icon: Icons.fingerprint,
              title: 'Biometric Login',
              subtitle: _biometricEnabled ? 'Enabled' : 'Disabled',
              onTap: () => _toggleBiometric(),
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: (value) => _toggleBiometric(),
                activeThumbColor: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildMenuGroup(
          'Account',
          [
            // Debug option - only show in debug mode
            if (kDebugMode && AppConfig.enableDebugMode)
              _MenuItemData(
                icon: Icons.bug_report,
                title: 'Generate Sample Users',
                subtitle: 'Create test accounts for development',
                onTap: () => _navigateToDebugScreen(context),
                textColor: Colors.orange,
              ),
            _MenuItemData(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              onTap: () => _logout(context),
              textColor: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuGroup(String title, List<_MenuItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppTheme.lightGrey,
                  ),
                _buildMenuItem(item),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(_MenuItemData item) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (item.textColor ?? AppTheme.primaryGreen).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          item.icon,
          color: item.textColor ?? AppTheme.primaryGreen,
          size: 20,
        ),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: item.textColor ?? AppTheme.darkGrey,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: TextStyle(
          color: AppTheme.grey,
          fontSize: 12,
        ),
      ),
      trailing: item.trailing ??
          Icon(
            Icons.chevron_right,
            color: AppTheme.grey,
          ),
      onTap: item.onTap,
    );
  }

  void _editProfile(BuildContext context) async {
    if (_profileData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile data not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(
          profileData: _profileData,
        ),
      ),
    );

    // Refresh profile data if editing was successful
    if (result == true) {
      _loadProfileData();
    }
  }

  void _showWalletDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletDetailsSheet(),
    );
  }

  void _addMoney(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Money'),
        content: const Text('Razorpay integration will be implemented for secure payments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add Money'),
          ),
        ],
      ),
    );
  }

  void _withdrawMoney(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Money'),
        content: const Text('Bank transfer functionality will be implemented with UPI integration.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _showSecuritySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: const Text('Security features including 2FA, password change, and biometric authentication will be implemented.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVerificationStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification Status'),
        content: const Text('KYC verification and document upload functionality will be implemented.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }



  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Text('Granular notification controls for orders, payments, and blockchain events will be implemented.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.pop(context);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('English'),
                    value: 'English',
                  ),
                  RadioListTile<String>(
                    title: const Text('हिंदी (Hindi)'),
                    value: 'Hindi',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _toggleBiometric() {
    setState(() {
      _biometricEnabled = !_biometricEnabled;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _biometricEnabled 
            ? 'Biometric login enabled' 
            : 'Biometric login disabled'
        ),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  void _navigateToDebugScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DebugSampleUsersScreen(),
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                debugPrint('🔓 Starting logout process...');
                
                // Clear app state first
                final appState = Provider.of<AppState>(context, listen: false);
                appState.clearUser();
                debugPrint('✅ App state cleared');
                
                // Sign out from Firebase - StreamBuilder will handle navigation
                await FirebaseAuth.instance.signOut();
                debugPrint('✅ Firebase signout complete');
                
                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: AppTheme.primaryGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('❌ Logout error: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showRatings(RatingType ratingType) {
    final appState = Provider.of<AppState>(context, listen: false);
    final currentUser = appState.currentUser;
    if (currentUser == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewRatingsScreen(
          userId: currentUser.id,
          userName: currentUser.name,
          initialTab: ratingType == RatingType.buyer ? 0 : 1,
        ),
      ),
    );
  }

  void _showAllRatings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllRatingsScreen(),
      ),
    );
  }

  // Helper method to create default rating stats
  dynamic _createDefaultRatingStats() {
    return _DefaultRatingStats();
  }
}

// Temporary class to provide default rating stats
class _DefaultRatingStats {
  final double averageRating = 0.0;
  final int totalRatings = 0;
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? textColor;

  _MenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.textColor,
  });
}

class _WalletDetailsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTransactionItem(
                    'Crop Purchase',
                    '- ₹2,500',
                    DateTime.now().subtract(const Duration(hours: 2)),
                    Icons.shopping_cart,
                    Colors.red,
                  ),
                  _buildTransactionItem(
                    'Wallet Top-up',
                    '+ ₹5,000',
                    DateTime.now().subtract(const Duration(days: 1)),
                    Icons.add_circle,
                    AppTheme.primaryGreen,
                  ),
                  _buildTransactionItem(
                    'Loan Repayment',
                    '- ₹1,200',
                    DateTime.now().subtract(const Duration(days: 3)),
                    Icons.payment,
                    Colors.red,
                  ),
                  _buildTransactionItem(
                    'Crop Sale',
                    '+ ₹3,800',
                    DateTime.now().subtract(const Duration(days: 5)),
                    Icons.sell,
                    AppTheme.primaryGreen,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    String title,
    String amount,
    DateTime date,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}