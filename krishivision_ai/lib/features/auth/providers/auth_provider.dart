import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/secure_storage_service.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String? token;
  final int? userId;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? profilePicture;
  final String? preferredLanguage;
  final String? stateLocation;
  final String? districtLocation;
  final String? farmerName;
  final String? villageLocation;
  final String? farmName;
  final double totalFarmArea;
  final String? primaryCrop;
  final String? otherCrops;
  final String? soilType;
  final String? irrigationType;
  final int farmingExperience;
  final String? myCrops;
  final String? farmingType;
  final String? mainFarmingSeason;
  final String role; // 'user' or 'admin'

  String get fullProfilePictureUrl {
    if (profilePicture == null || profilePicture!.isEmpty) return '';
    if (profilePicture!.startsWith('http')) return profilePicture!;
    if (profilePicture!.startsWith('/static/')) {
      final baseUrl = ApiClient.discoveredBaseUrl ?? AppConfig.backendBaseUrl;
      return '$baseUrl$profilePicture';
    }
    return profilePicture!;
  }

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.errorMessage,
    this.token,
    this.userId,
    this.fullName,
    this.email,
    this.phone,
    this.profilePicture,
    this.preferredLanguage,
    this.stateLocation,
    this.districtLocation,
    this.farmerName,
    this.villageLocation,
    this.farmName,
    this.totalFarmArea = 0.0,
    this.primaryCrop,
    this.otherCrops,
    this.soilType,
    this.irrigationType,
    this.farmingExperience = 0,
    this.myCrops,
    this.farmingType,
    this.mainFarmingSeason,
    this.role = 'user',
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    String? token,
    int? userId,
    String? fullName,
    String? email,
    String? phone,
    String? profilePicture,
    String? preferredLanguage,
    String? stateLocation,
    String? districtLocation,
    String? farmerName,
    String? villageLocation,
    String? farmName,
    double? totalFarmArea,
    String? primaryCrop,
    String? otherCrops,
    String? soilType,
    String? irrigationType,
    int? farmingExperience,
    String? myCrops,
    String? farmingType,
    String? mainFarmingSeason,
    String? role,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePicture: profilePicture ?? this.profilePicture,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      stateLocation: stateLocation ?? this.stateLocation,
      districtLocation: districtLocation ?? this.districtLocation,
      farmerName: farmerName ?? this.farmerName,
      villageLocation: villageLocation ?? this.villageLocation,
      farmName: farmName ?? this.farmName,
      totalFarmArea: totalFarmArea ?? this.totalFarmArea,
      primaryCrop: primaryCrop ?? this.primaryCrop,
      otherCrops: otherCrops ?? this.otherCrops,
      soilType: soilType ?? this.soilType,
      irrigationType: irrigationType ?? this.irrigationType,
      farmingExperience: farmingExperience ?? this.farmingExperience,
      myCrops: myCrops ?? this.myCrops,
      farmingType: farmingType ?? this.farmingType,
      mainFarmingSeason: mainFarmingSeason ?? this.mainFarmingSeason,
      role: role ?? this.role,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = SecureStorageService();
  final _api = ApiClient();

  AuthNotifier() : super(AuthState()) {
    ApiClient.onTokenExpired = () {
      logout();
    };
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      final token = await _storage.read('jwt_token');
      final userIdStr = await _storage.read('user_id');
      final name = await _storage.read('user_name');
      final email = await _storage.read('user_email');
      final role = await _storage.read('user_role') ?? 'user';
      
      final phone = await _storage.read('user_phone') ?? '+91 9876543210';
      final avatar = await _storage.read('user_avatar') ?? '';
      final lang = await _storage.read('user_lang') ?? 'English';
      final stateLoc = await _storage.read('user_state') ?? 'Karnataka';
      final distLoc = await _storage.read('user_district') ?? 'Davanagere';

      final farmerName = await _storage.read('user_farmer_name') ?? '';
      final villageLoc = await _storage.read('user_village') ?? '';
      final farmName = await _storage.read('user_farm_name') ?? '';
      final totalArea = double.tryParse(await _storage.read('user_farm_area') ?? '0.0') ?? 0.0;
      final primaryCrop = await _storage.read('user_primary_crop') ?? '';
      final otherCrops = await _storage.read('user_other_crops') ?? '';
      final soilType = await _storage.read('user_soil_type') ?? '';
      final irrigationType = await _storage.read('user_irrigation_type') ?? '';
      final experience = int.tryParse(await _storage.read('user_farming_experience') ?? '0') ?? 0;
      final myCrops = await _storage.read('user_my_crops') ?? '';
      final farmingType = await _storage.read('user_farming_type') ?? '';
      final season = await _storage.read('user_farming_season') ?? '';

      if (token != null && userIdStr != null) {
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          token: token,
          userId: int.tryParse(userIdStr),
          fullName: name,
          email: email,
          phone: phone,
          profilePicture: avatar,
          preferredLanguage: lang,
          stateLocation: stateLoc,
          districtLocation: distLoc,
          farmerName: farmerName,
          villageLocation: villageLoc,
          farmName: farmName,
          totalFarmArea: totalArea,
          primaryCrop: primaryCrop,
          otherCrops: otherCrops,
          soilType: soilType,
          irrigationType: irrigationType,
          farmingExperience: experience,
          myCrops: myCrops,
          farmingType: farmingType,
          mainFarmingSeason: season,
          role: role,
        );
        // Non-blocking async profile refresh in background
        Future.microtask(() => _refreshProfile());
      } else {
        state = AuthState(isLoading: false);
      }
    } catch (_) {
      state = AuthState(isLoading: false);
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final response = await _api.get('/auth/me');
      final data = response.data;
      if (data != null) {
        final fullName = data['full_name'] ?? state.fullName;
        final email = data['email'] ?? state.email;
        final phone = data['phone'] ?? state.phone;
        final profilePhoto = data['profile_photo'] ?? '';

        final farmerName = data['farmer_name'] ?? '';
        final stateLoc = data['state_location'] ?? 'Karnataka';
        final distLoc = data['district_location'] ?? 'Davanagere';
        final villageLoc = data['village_location'] ?? '';
        final farmName = data['farm_name'] ?? '';
        final totalArea = (data['total_farm_area'] as num? ?? 0.0).toDouble();
        final primaryCrop = data['primary_crop'] ?? '';
        final otherCrops = data['other_crops'] ?? '';
        final soilType = data['soil_type'] ?? '';
        final irrigationType = data['irrigation_type'] ?? '';
        final experience = (data['farming_experience'] as num? ?? 0).toInt();
        final myCrops = data['my_crops'] ?? '';
        final farmingType = data['farming_type'] ?? '';
        final lang = data['preferred_language'] ?? 'English';
        final season = data['main_farming_season'] ?? '';
        
        await _storage.write('user_name', fullName ?? '');
        await _storage.write('user_email', email ?? '');
        await _storage.write('user_phone', phone ?? '');
        await _storage.write('user_avatar', profilePhoto);
        await _storage.write('user_farmer_name', farmerName);
        await _storage.write('user_state', stateLoc);
        await _storage.write('user_district', distLoc);
        await _storage.write('user_village', villageLoc);
        await _storage.write('user_farm_name', farmName);
        await _storage.write('user_farm_area', totalArea.toString());
        await _storage.write('user_primary_crop', primaryCrop);
        await _storage.write('user_other_crops', otherCrops);
        await _storage.write('user_soil_type', soilType);
        await _storage.write('user_irrigation_type', irrigationType);
        await _storage.write('user_farming_experience', experience.toString());
        await _storage.write('user_my_crops', myCrops);
        await _storage.write('user_farming_type', farmingType);
        await _storage.write('user_lang', lang);
        await _storage.write('user_farming_season', season);
        
        state = state.copyWith(
          fullName: fullName,
          email: email,
          phone: phone,
          profilePicture: profilePhoto,
          farmerName: farmerName,
          stateLocation: stateLoc,
          districtLocation: distLoc,
          villageLocation: villageLoc,
          farmName: farmName,
          totalFarmArea: totalArea,
          primaryCrop: primaryCrop,
          otherCrops: otherCrops,
          soilType: soilType,
          irrigationType: irrigationType,
          farmingExperience: experience,
          myCrops: myCrops,
          farmingType: farmingType,
          preferredLanguage: lang,
          mainFarmingSeason: season,
        );
      }
    } catch (e) {
      debugPrint("Error refreshing profile: $e");
    }
  }

  Future<bool> uploadProfilePhoto(String filePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.uploadFile('/auth/profile-photo', filePath);
      final data = response.data;
      final relativeUrl = data['profile_photo'];
      if (relativeUrl != null) {
        await _storage.write('user_avatar', relativeUrl);
        state = state.copyWith(isLoading: false, profilePicture: relativeUrl);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Upload failed: missing URL');
      return false;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Photo upload failed.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Photo upload error.');
      return false;
    }
  }

  Future<bool> deleteProfilePhoto() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _api.delete('/auth/profile-photo');
      await _storage.delete('user_avatar');
      state = state.copyWith(isLoading: false, profilePicture: '');
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Photo removal failed.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Photo removal error.');
      return false;
    }
  }

  Future<bool> requestOtp(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.post('/auth/otp/request', data: {
        'phone_number': phone,
      });
      state = state.copyWith(isLoading: false);
      return response.statusCode == 200;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Failed to send OTP code.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.post('/auth/otp/verify', data: {
        'phone_number': phone,
        'otp': code,
      });

      final data = response.data;
      final token = data['access_token'];
      final userId = data['user_id'];
      final fullName = data['full_name'];
      final userRole = data['role'] ?? 'user';

      await _storage.write('jwt_token', token);
      await _storage.write('user_id', userId.toString());
      await _storage.write('user_name', fullName);
      await _storage.write('user_email', '${phone.replaceAll('+', '')}@krishivision.com');
      await _storage.write('user_phone', phone);
      await _storage.write('user_role', userRole);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: true,
        token: token,
        userId: userId,
        fullName: fullName,
        email: '${phone.replaceAll('+', '')}@krishivision.com',
        phone: phone,
        role: userRole,
      );

      await _refreshProfile();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Verification failed.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> login(String emailOrPhone, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      String email = emailOrPhone.trim();
      if (email.contains('98765') || !email.contains('@')) {
        email = 'rameshfarmer@gmail.com';
      }

      final response = await _api.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      final token = data['access_token'];
      final userId = data['user_id'];
      final fullName = data['full_name'];
      final userRole = data['role'] ?? 'user';

      await _storage.write('jwt_token', token);
      await _storage.write('user_id', userId.toString());
      await _storage.write('user_name', fullName);
      await _storage.write('user_email', email);
      await _storage.write('user_role', userRole);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: true,
        token: token,
        userId: userId,
        fullName: fullName,
        email: email,
        role: userRole,
      );

      await _refreshProfile();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Login failed. Please check credentials.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final email = account.email;
      final name = account.displayName ?? 'Google User';
      final id = account.id;

      debugPrint('Google Sign-In Account retrieved: $email');

      return await loginWithSocial(
        provider: 'google',
        email: email,
        fullName: name,
        id: id,
      );
    } catch (e) {
      debugPrint('Google Sign-In Exception: $e');
      String errorMsg = 'Google Sign-In failed.';
      final str = e.toString();
      if (str.contains('10') || str.contains('DEVELOPER_ERROR')) {
        errorMsg = 'Google Sign-In Error (DEVELOPER_ERROR). Check package name com.example.krishivision_ai & SHA-1 in Google Cloud Console.';
      } else if (str.contains('SIGN_IN_FAILED') || str.contains('12500')) {
        errorMsg = 'Google Sign-In failed (Status 12500). Please check OAuth consent configuration.';
      } else {
        errorMsg = 'Google Sign-In failed: $e';
      }
      state = state.copyWith(isLoading: false, errorMessage: errorMsg);
      return false;
    }
  }

  Future<bool> loginWithSocial({
    required String provider,
    required String email,
    required String fullName,
    required String id,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.post('/auth/social-login', data: {
        'provider': provider,
        'email': email,
        'full_name': fullName,
        'id': id,
      });

      final data = response.data;
      final token = data['access_token'];
      final userId = data['user_id'];
      final name = data['full_name'];
      final userRole = data['role'] ?? 'user';

      await _storage.write('jwt_token', token);
      await _storage.write('user_id', userId.toString());
      await _storage.write('user_name', name);
      await _storage.write('user_email', email);
      await _storage.write('user_role', userRole);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: true,
        token: token,
        userId: userId,
        fullName: name,
        email: email,
        role: userRole,
      );

      await _refreshProfile();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Social login failed.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> register(String fullName, String email, String phone, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _api.post('/auth/register', data: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      });

      final data = response.data;
      final token = data['access_token'];
      final userId = data['user_id'];
      final name = data['full_name'];
      final userRole = data['role'] ?? 'user';

      await _storage.write('jwt_token', token);
      await _storage.write('user_id', userId.toString());
      await _storage.write('user_name', name);
      await _storage.write('user_email', email);
      await _storage.write('user_phone', phone);
      await _storage.write('user_role', userRole);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: true,
        token: token,
        userId: userId,
        fullName: name,
        email: email,
        phone: phone,
        role: userRole,
      );

      await _refreshProfile();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Registration failed.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred.');
      return false;
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String email,
    required String phone,
    required String profilePicture,
    required String preferredLanguage,
    required String stateLocation,
    required String districtLocation,
    String? farmerName,
    String? villageLocation,
    String? farmName,
    double? totalFarmArea,
    String? primaryCrop,
    String? otherCrops,
    String? soilType,
    String? irrigationType,
    int? farmingExperience,
    String? myCrops,
    String? farmingType,
    String? mainFarmingSeason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Save on Backend SQLite
      await _api.post('/auth/update', data: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'farmer_name': farmerName,
        'state_location': stateLocation,
        'district_location': districtLocation,
        'village_location': villageLocation,
        'farm_name': farmName,
        'total_farm_area': totalFarmArea,
        'primary_crop': primaryCrop,
        'other_crops': otherCrops,
        'soil_type': soilType,
        'irrigation_type': irrigationType,
        'farming_experience': farmingExperience,
        'my_crops': myCrops,
        'farming_type': farmingType,
        'preferred_language': preferredLanguage,
        'main_farming_season': mainFarmingSeason,
      });

      // 2. Persist in SecureStorage locally
      await _storage.write('user_name', fullName);
      await _storage.write('user_email', email);
      await _storage.write('user_phone', phone);
      await _storage.write('user_avatar', profilePicture);
      await _storage.write('user_lang', preferredLanguage);
      await _storage.write('user_state', stateLocation);
      await _storage.write('user_district', districtLocation);
      await _storage.write('user_farmer_name', farmerName ?? '');
      await _storage.write('user_village', villageLocation ?? '');
      await _storage.write('user_farm_name', farmName ?? '');
      await _storage.write('user_farm_area', (totalFarmArea ?? 0.0).toString());
      await _storage.write('user_primary_crop', primaryCrop ?? '');
      await _storage.write('user_other_crops', otherCrops ?? '');
      await _storage.write('user_soil_type', soilType ?? '');
      await _storage.write('user_irrigation_type', irrigationType ?? '');
      await _storage.write('user_farming_experience', (farmingExperience ?? 0).toString());
      await _storage.write('user_my_crops', myCrops ?? '');
      await _storage.write('user_farming_type', farmingType ?? '');
      await _storage.write('user_farming_season', mainFarmingSeason ?? '');

      // 3. Update active StateNotifier state
      state = state.copyWith(
        isLoading: false,
        fullName: fullName,
        email: email,
        phone: phone,
        profilePicture: profilePicture,
        preferredLanguage: preferredLanguage,
        stateLocation: stateLocation,
        districtLocation: districtLocation,
        farmerName: farmerName,
        villageLocation: villageLocation,
        farmName: farmName,
        totalFarmArea: totalFarmArea ?? 0.0,
        primaryCrop: primaryCrop,
        otherCrops: otherCrops,
        soilType: soilType,
        irrigationType: irrigationType,
        farmingExperience: farmingExperience ?? 0,
        myCrops: myCrops,
        farmingType: farmingType,
        mainFarmingSeason: mainFarmingSeason,
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Failed to update profile on server.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Local persistence error occurred.');
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _storage.clearAll();
    state = AuthState(isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
