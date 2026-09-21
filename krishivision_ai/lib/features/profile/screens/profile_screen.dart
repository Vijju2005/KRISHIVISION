import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/bottom_nav.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import 'crop_screen.dart';
import '../../../core/services/api_client.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _stateController;
  late TextEditingController _districtController;

  late TextEditingController _farmerNameController;
  late TextEditingController _villageController;
  late TextEditingController _farmNameController;
  late TextEditingController _totalAreaController;
  late TextEditingController _primaryCropController;
  late TextEditingController _otherCropsController;
  late TextEditingController _experienceController;

  String _selectedLanguage = 'English';
  String _selectedSoilType = 'Clay';
  String _selectedIrrigationType = 'Drip';
  String _selectedFarmingType = 'Organic';
  String _selectedSeason = 'Kharif';
  List<String> _selectedCrops = [];

  File? _tempPhotoFile;
  bool _isSavingPhoto = false;
  List<String> _dbCrops = [];
  bool _isLoadingCrops = false;

  final List<String> _soilTypes = ['Clay', 'Sandy', 'Loamy', 'Silt', 'Black Soil', 'Red Soil', 'Laterite'];
  final List<String> _irrigationTypes = ['Drip', 'Sprinkler', 'Flood', 'Rainfed', 'Canal'];
  final List<String> _farmingTypes = ['Organic', 'Conventional', 'Natural Farming', 'Precision Farming'];
  final List<String> _seasons = ['Kharif', 'Rabi', 'Zaid'];

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _nameController = TextEditingController(text: auth.fullName);
    _emailController = TextEditingController(text: auth.email);
    _phoneController = TextEditingController(text: auth.phone);
    _stateController = TextEditingController(text: auth.stateLocation ?? 'Karnataka');
    _districtController = TextEditingController(text: auth.districtLocation ?? 'Davanagere');

    _farmerNameController = TextEditingController(text: auth.farmerName);
    _villageController = TextEditingController(text: auth.villageLocation);
    _farmNameController = TextEditingController(text: auth.farmName);
    _totalAreaController = TextEditingController(text: auth.totalFarmArea > 0 ? auth.totalFarmArea.toString() : '');
    _primaryCropController = TextEditingController(text: auth.primaryCrop);
    _otherCropsController = TextEditingController(text: auth.otherCrops);
    _experienceController = TextEditingController(text: auth.farmingExperience > 0 ? auth.farmingExperience.toString() : '');

    _selectedLanguage = auth.preferredLanguage ?? 'English';
    _selectedSoilType = (auth.soilType != null && auth.soilType!.isNotEmpty) ? auth.soilType! : 'Clay';
    _selectedIrrigationType = (auth.irrigationType != null && auth.irrigationType!.isNotEmpty) ? auth.irrigationType! : 'Drip';
    _selectedFarmingType = (auth.farmingType != null && auth.farmingType!.isNotEmpty) ? auth.farmingType! : 'Organic';
    _selectedSeason = (auth.mainFarmingSeason != null && auth.mainFarmingSeason!.isNotEmpty) ? auth.mainFarmingSeason! : 'Kharif';

    if (auth.myCrops != null && auth.myCrops!.isNotEmpty) {
      _selectedCrops = auth.myCrops!.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    } else {
      _selectedCrops = [];
    }

    _loadCropsFromDb();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _stateController.dispose();
    _districtController.dispose();

    _farmerNameController.dispose();
    _villageController.dispose();
    _farmNameController.dispose();
    _totalAreaController.dispose();
    _primaryCropController.dispose();
    _otherCropsController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _loadCropsFromDb() async {
    setState(() => _isLoadingCrops = true);
    try {
      final client = ApiClient();
      final response = await client.get('/crops/all-names');
      if (response.statusCode == 200) {
        final List<dynamic> list = response.data;
        setState(() {
          _dbCrops = list.map((e) => e.toString()).toList();
        });
      }
    } catch (_) {
      // Keep defaults if offline
    } finally {
      setState(() => _isLoadingCrops = false);
    }
  }

  void _startEditing() {
    final auth = ref.read(authProvider);
    setState(() {
      _nameController.text = auth.fullName ?? '';
      _emailController.text = auth.email ?? '';
      _phoneController.text = auth.phone ?? '';
      _stateController.text = auth.stateLocation ?? 'Karnataka';
      _districtController.text = auth.districtLocation ?? 'Davanagere';
      _selectedLanguage = auth.preferredLanguage ?? 'English';
      
      _farmerNameController.text = auth.farmerName ?? '';
      _villageController.text = auth.villageLocation ?? '';
      _farmNameController.text = auth.farmName ?? '';
      _totalAreaController.text = auth.totalFarmArea > 0 ? auth.totalFarmArea.toString() : '';
      _primaryCropController.text = auth.primaryCrop ?? '';
      _otherCropsController.text = auth.otherCrops ?? '';
      _experienceController.text = auth.farmingExperience > 0 ? auth.farmingExperience.toString() : '';

      _selectedSoilType = (auth.soilType != null && auth.soilType!.isNotEmpty) ? auth.soilType! : 'Clay';
      _selectedIrrigationType = (auth.irrigationType != null && auth.irrigationType!.isNotEmpty) ? auth.irrigationType! : 'Drip';
      _selectedFarmingType = (auth.farmingType != null && auth.farmingType!.isNotEmpty) ? auth.farmingType! : 'Organic';
      _selectedSeason = (auth.mainFarmingSeason != null && auth.mainFarmingSeason!.isNotEmpty) ? auth.mainFarmingSeason! : 'Kharif';

      if (auth.myCrops != null && auth.myCrops!.isNotEmpty) {
        _selectedCrops = auth.myCrops!.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      } else {
        _selectedCrops = [];
      }
      
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authProvider);
    final success = await ref.read(authProvider.notifier).updateProfile(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      profilePicture: auth.profilePicture ?? '',
      preferredLanguage: _selectedLanguage,
      stateLocation: _stateController.text.trim(),
      districtLocation: _districtController.text.trim(),
      farmerName: _farmerNameController.text.trim(),
      villageLocation: _villageController.text.trim(),
      farmName: _farmNameController.text.trim(),
      totalFarmArea: double.tryParse(_totalAreaController.text.trim()) ?? 0.0,
      farmingExperience: int.tryParse(_experienceController.text.trim()) ?? 0,
      primaryCrop: _primaryCropController.text.trim(),
      otherCrops: _otherCropsController.text.trim(),
      soilType: _selectedSoilType,
      irrigationType: _selectedIrrigationType,
      farmingType: _selectedFarmingType,
      mainFarmingSeason: _selectedSeason,
      myCrops: _selectedCrops.join(','),
    );

    if (success) {
      setState(() {
        _isEditing = false;
      });
      ref.read(dashboardProvider.notifier).loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.healthy,
          ),
        );
      }
    } else {
      if (mounted) {
        final error = ref.read(authProvider).errorMessage ?? 'Update failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickAndCropImageOption() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      
      if (pickedFile == null) return;
      
      if (!mounted) return;
      
      final croppedFile = await Navigator.of(context).push<File?>(
        MaterialPageRoute(
          builder: (context) => CropScreen(imageFile: File(pickedFile.path)),
        ),
      );
      
      if (croppedFile != null && mounted) {
        setState(() {
          _tempPhotoFile = croppedFile;
        });
        await _savePhotoPermanently();
      }
    } on PlatformException catch (e) {
      debugPrint("Platform exception picking image: $e");
      String errorMsg = "Selection failed or permission denied.";
      if (e.code == 'photo_access_denied') {
        errorMsg = "Gallery access denied. Please grant photo library permission in settings.";
      } else if (e.code == 'camera_access_denied') {
        errorMsg = "Camera access denied. Please grant camera permission in settings.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error picking/cropping image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gallery selection failed or permission denied: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _savePhotoPermanently() async {
    if (_tempPhotoFile == null) return;
    setState(() {
      _isSavingPhoto = true;
    });
    try {
      final success = await ref.read(authProvider.notifier).uploadProfilePhoto(_tempPhotoFile!.path);
      if (success) {
        setState(() {
          _tempPhotoFile = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: AppColors.healthy,
            ),
          );
        }
      } else {
        if (mounted) {
          final error = ref.read(authProvider).errorMessage ?? 'Failed to upload photo';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving photo: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPhoto = false;
        });
      }
    }
  }

  Future<void> _removePhoto() async {
    final success = await ref.read(authProvider.notifier).deleteProfilePhoto();
    if (success && mounted) {
      setState(() {
        _tempPhotoFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo removed successfully!'),
          backgroundColor: AppColors.healthy,
        ),
      );
    } else if (mounted) {
      final error = ref.read(authProvider).errorMessage ?? 'Failed to remove photo';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildLargeAvatar(AuthState auth, bool isDark) {
    return Center(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary,
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 65,
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              child: ClipOval(
                child: _tempPhotoFile != null
                    ? Image.file(
                        _tempPhotoFile!,
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                      )
                    : (auth.profilePicture != null && auth.profilePicture!.isNotEmpty)
                        ? (auth.profilePicture!.startsWith('http') || auth.profilePicture!.startsWith('/static/'))
                            ? Image.network(
                                auth.fullProfilePictureUrl,
                                width: 130,
                                height: 130,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/app_logo.png',
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                            : File(auth.profilePicture!).existsSync()
                                ? Image.file(
                                    File(auth.profilePicture!),
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    'assets/app_logo.png',
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.cover,
                                  )
                        : Image.asset(
                            'assets/app_logo.png',
                            width: 130,
                            height: 130,
                            fit: BoxFit.cover,
                          ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: GestureDetector(
              onTap: _pickAndCropImageOption,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(AuthState auth, bool isDark) {
    return Column(
      children: [
        _buildLargeAvatar(auth, isDark),
        if (_isSavingPhoto) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      ],
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English (US)'),
                trailing: _selectedLanguage == 'English' ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _selectedLanguage = 'English');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('ಕನ್ನಡ (Kannada)'),
                trailing: _selectedLanguage == 'Kannada' ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _selectedLanguage = 'Kannada');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('हिंदी (Hindi)'),
                trailing: _selectedLanguage == 'Hindi' ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _selectedLanguage = 'Hindi');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFarmsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('My Registered Farms'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: const [
                ListTile(
                  leading: Icon(Icons.landscape, color: AppColors.primary),
                  title: Text('Davanagere Main Farm'),
                  subtitle: Text('2.5 Acres • Rice Crop'),
                ),
                ListTile(
                  leading: Icon(Icons.landscape, color: AppColors.primary),
                  title: Text('Haveri Plot B'),
                  subtitle: Text('1.8 Acres • Maize Crop'),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFarmOverviewSection(AuthState auth, bool isDark) {
    final dashState = ref.watch(dashboardProvider);
    if (dashState.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    final stats = dashState.stats;
    final monitored = dashState.monitoredCrops;
    final cropsListStr = monitored.isEmpty ? 'No crops analyzed' : monitored.join(', ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      color: isDark ? AppColors.darkCard : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'My Farm Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            
            _buildOverviewRow('Total Farm Area', '${auth.totalFarmArea} Acres', Icons.landscape_outlined, AppColors.primary),
            _buildOverviewRow('Crops Being Monitored', cropsListStr, Icons.grass_outlined, AppColors.healthy),
            _buildOverviewRow('Total Analyses', '${stats.totalAnalysis}', Icons.analytics_outlined, AppColors.info),
            _buildOverviewRow('Healthy Area', '${stats.healthyAreaAcres} Acres', Icons.favorite_border_rounded, AppColors.healthy),
            _buildOverviewRow('At-Risk Area', '${stats.atRiskAreaAcres} Acres', Icons.warning_amber_rounded, AppColors.atRisk),
            _buildOverviewRow('Upcoming Harvests', '${stats.upcomingHarvestCount} Crops', Icons.alarm_rounded, AppColors.info),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.08),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: 4,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  flex: 5,
                  child: Text(
                    value,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'Farmer Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _startEditing,
            ),
        ],
      ),
      body: _isEditing ? _buildEditForm(isDark) : _buildReadOnlyProfile(authState, isDark),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildReadOnlyProfile(AuthState auth, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildAvatarSection(auth, isDark),
        const SizedBox(height: 20),

        Center(
          child: Column(
            children: [
              Text(
                auth.fullName ?? 'Farmer Profile',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                auth.email ?? '',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ElevatedButton(
            onPressed: _startEditing,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 1,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ),
        
        // Farm overview (dashboard)
        _buildFarmOverviewSection(auth, isDark),

        // My Crops section
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.grass, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'My Crops',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: _selectedCrops.isEmpty
              ? const Text(
                  'No crops selected in preferences. Edit profile to select crops.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedCrops.map((crop) {
                    return Chip(
                      label: Text(crop),
                      backgroundColor: AppColors.primary.withOpacity(0.08),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                    );
                  }).toList(),
                ),
        ),

        // Personal Information
        _buildInfoSection(
          'Personal Information',
          [
            _buildReadOnlyTile(Icons.person_outline, 'Full Name', auth.fullName ?? ''),
            _buildReadOnlyTile(Icons.phone_outlined, 'Mobile Number', auth.phone ?? ''),
            _buildReadOnlyTile(Icons.email_outlined, 'Email Address', auth.email ?? ''),
          ],
          isDark,
        ),
        
        // Farmer Information
        _buildInfoSection(
          'Farmer / Agriculture Information',
          [
            _buildReadOnlyTile(Icons.assignment_ind_outlined, 'Farmer Name', auth.farmerName != null && auth.farmerName!.isNotEmpty ? auth.farmerName! : 'Not specified'),
            _buildReadOnlyTile(Icons.location_on_outlined, 'State', auth.stateLocation ?? 'Not specified'),
            _buildReadOnlyTile(Icons.location_city_outlined, 'District', auth.districtLocation ?? 'Not specified'),
            _buildReadOnlyTile(Icons.home_work_outlined, 'Village / Location', auth.villageLocation != null && auth.villageLocation!.isNotEmpty ? auth.villageLocation! : 'Not specified'),
            _buildReadOnlyTile(Icons.park_outlined, 'Farm Name', auth.farmName != null && auth.farmName!.isNotEmpty ? auth.farmName! : 'Not specified'),
            _buildReadOnlyTile(Icons.square_foot_outlined, 'Total Farm Area', '${auth.totalFarmArea} Acres'),
            _buildReadOnlyTile(Icons.grass_outlined, 'Primary Crop', auth.primaryCrop != null && auth.primaryCrop!.isNotEmpty ? auth.primaryCrop! : 'Not specified'),
            _buildReadOnlyTile(Icons.nature_outlined, 'Other Crops', auth.otherCrops != null && auth.otherCrops!.isNotEmpty ? auth.otherCrops! : 'Not specified'),
            _buildReadOnlyTile(Icons.psychology_outlined, 'Farming Experience', '${auth.farmingExperience} Years'),
          ],
          isDark,
        ),

        // Farming Preferences
        _buildInfoSection(
          'My Farming Preferences',
          [
            _buildReadOnlyTile(Icons.layers_outlined, 'Soil Type', auth.soilType != null && auth.soilType!.isNotEmpty ? auth.soilType! : 'Not specified'),
            _buildReadOnlyTile(Icons.water_drop_outlined, 'Irrigation Method', auth.irrigationType != null && auth.irrigationType!.isNotEmpty ? auth.irrigationType! : 'Not specified'),
            _buildReadOnlyTile(Icons.eco_outlined, 'Farming Type', auth.farmingType != null && auth.farmingType!.isNotEmpty ? auth.farmingType! : 'Not specified'),
            _buildReadOnlyTile(Icons.calendar_today_outlined, 'Main Farming Season', auth.mainFarmingSeason != null && auth.mainFarmingSeason!.isNotEmpty ? auth.mainFarmingSeason! : 'Not specified'),
            _buildReadOnlyTile(Icons.language_rounded, 'Preferred Language', auth.preferredLanguage ?? 'English'),
          ],
          isDark,
        ),
        const SizedBox(height: 20),

        // Menu lists
        _ProfileMenuTile(
          icon: Icons.landscape_outlined,
          label: 'My Registered Farms',
          onTap: _showFarmsDialog,
        ),
        _ProfileMenuTile(
          icon: Icons.language_rounded,
          label: 'Preferred Language (${auth.preferredLanguage ?? 'English'})',
          onTap: () {
            _showLanguageDialog();
            Future.delayed(const Duration(milliseconds: 300), () {
              ref.read(authProvider.notifier).updateProfile(
                fullName: auth.fullName ?? '',
                email: auth.email ?? '',
                phone: auth.phone ?? '',
                profilePicture: auth.profilePicture ?? '',
                preferredLanguage: _selectedLanguage,
                stateLocation: auth.stateLocation ?? 'Karnataka',
                districtLocation: auth.districtLocation ?? 'Davanagere',
                farmerName: auth.farmerName,
                villageLocation: auth.villageLocation,
                farmName: auth.farmName,
                totalFarmArea: auth.totalFarmArea,
                farmingExperience: auth.farmingExperience,
                primaryCrop: auth.primaryCrop,
                otherCrops: auth.otherCrops,
                soilType: auth.soilType,
                irrigationType: auth.irrigationType,
                farmingType: auth.farmingType,
                mainFarmingSeason: auth.mainFarmingSeason,
                myCrops: auth.myCrops,
              );
            });
          },
        ),
        _ProfileMenuTile(
          icon: Icons.dark_mode_outlined,
          label: 'Theme Customization',
          trailing: Switch(
            value: isDark,
            activeColor: AppColors.primary,
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).toggleTheme(val);
            },
          ),
          onTap: () {},
        ),
        _ProfileMenuTile(
          icon: Icons.settings_ethernet_rounded,
          label: 'API Server Settings',
          onTap: () => context.push('/api-settings'),
        ),
        if (auth.role == 'admin')
          _ProfileMenuTile(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Administrative Terminal',
            onTap: () => context.push('/admin'),
          ),
        _ProfileMenuTile(
          icon: Icons.help_outline_rounded,
          label: 'Help & Customer Support',
          onTap: () {
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Contact Support'),
                content: const Text(
                  'Having issues? Reach out to support:\n\nEmail: support@krishivision.ai\nPhone: 1800-123-4567',
                ),
                actions: [
                  ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('Ok')),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text(
              'Logout Session',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
            onTap: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/app_logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'KrishiVision',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
              const Text(
                'v1.0.0 • Smart Satellite Crop Monitoring',
                style: TextStyle(fontSize: 10, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEditForm(bool isDark) {
    final auth = ref.watch(authProvider);
    final allCrops = {
      'Rice', 'Wheat', 'Maize', 'Sugarcane', 'Cotton', 'Groundnut', 'Soybean', 
      'Pulses', 'Chickpea', 'Tomato', 'Onion', 'Potato', 'Banana', 'Coconut', 
      'Arecanut', 'Coffee', 'Tea', 'Black Pepper', 'Cardamom', 'Turmeric', 
      'Ginger', 'Mustard', ..._dbCrops
    }.toList();
    allCrops.sort();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildAvatarSection(auth, isDark),
          const SizedBox(height: 28),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Farmer / Agriculture Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          TextFormField(
            controller: _farmerNameController,
            decoration: const InputDecoration(
              labelText: 'Farmer Name',
              prefixIcon: Icon(Icons.assignment_ind_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter farmer name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _districtController,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    prefixIcon: Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter District';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    prefixIcon: Icon(Icons.map_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter State';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _villageController,
            decoration: const InputDecoration(
              labelText: 'Village / Location',
              prefixIcon: Icon(Icons.home_work_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _farmNameController,
            decoration: const InputDecoration(
              labelText: 'Farm Name (Optional)',
              prefixIcon: Icon(Icons.park_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _totalAreaController,
                  decoration: const InputDecoration(
                    labelText: 'Total Farm Area (Acres)',
                    prefixIcon: Icon(Icons.square_foot_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _experienceController,
                  decoration: const InputDecoration(
                    labelText: 'Farming Experience (Years)',
                    prefixIcon: Icon(Icons.psychology_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _primaryCropController,
                  decoration: const InputDecoration(
                    labelText: 'Primary Crop',
                    prefixIcon: Icon(Icons.grass),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _otherCropsController,
                  decoration: const InputDecoration(
                    labelText: 'Other Crops',
                    prefixIcon: Icon(Icons.nature),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('My Farming Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          DropdownButtonFormField<String>(
            value: _soilTypes.contains(_selectedSoilType) ? _selectedSoilType : _soilTypes.first,
            decoration: const InputDecoration(
              labelText: 'Soil Type',
              prefixIcon: Icon(Icons.layers_outlined),
              border: OutlineInputBorder(),
            ),
            items: _soilTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedSoilType = val);
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _irrigationTypes.contains(_selectedIrrigationType) ? _selectedIrrigationType : _irrigationTypes.first,
            decoration: const InputDecoration(
              labelText: 'Irrigation Method',
              prefixIcon: Icon(Icons.water_drop_outlined),
              border: OutlineInputBorder(),
            ),
            items: _irrigationTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedIrrigationType = val);
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _farmingTypes.contains(_selectedFarmingType) ? _selectedFarmingType : _farmingTypes.first,
            decoration: const InputDecoration(
              labelText: 'Farming Type',
              prefixIcon: Icon(Icons.eco_outlined),
              border: OutlineInputBorder(),
            ),
            items: _farmingTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedFarmingType = val);
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _seasons.contains(_selectedSeason) ? _selectedSeason : _seasons.first,
            decoration: const InputDecoration(
              labelText: 'Main Farming Season',
              prefixIcon: Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(),
            ),
            items: _seasons.map((season) {
              return DropdownMenuItem(value: season, child: Text(season));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedSeason = val);
            },
          ),
          const SizedBox(height: 16),

          ListTile(
            title: const Text('Preferred Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(_selectedLanguage),
            trailing: const Icon(Icons.arrow_drop_down),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.grey, width: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            onTap: _showLanguageDialog,
          ),
          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('My Crops Selection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          if (_isLoadingCrops)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: AppColors.primary)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allCrops.map((crop) {
                final isSelected = _selectedCrops.contains(crop);
                return FilterChip(
                  label: Text(crop),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCrops.add(crop);
                      } else {
                        _selectedCrops.remove(crop);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelEditing,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _ProfileMenuTile({required this.icon, required this.label, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.08),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey, size: 20),
        onTap: onTap,
      ),
    );
  }
}
