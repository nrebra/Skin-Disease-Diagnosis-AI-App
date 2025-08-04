import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skincancer/service/authService.dart';
import 'package:skincancer/pages/auth/LoginPage.dart';
import 'package:skincancer/style/color.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class Information extends StatefulWidget {
  final String email;
  final String password;
  final String surname;
  final String name;
  final String userType;

  const Information({
    super.key,
    required this.email,
    required this.password,
    required this.surname,
    required this.name,
    required this.userType,
  });

  @override
  _InformationState createState() => _InformationState();
}

class _InformationState extends State<Information> {
  int _currentStep = 0;
  int _gender = 0;
  int _age = 30;
  String _speciality = '';
  int _experience = 0;
  String _tcNumber = '';
  String _phoneNumber = '';
  String _location = '';
  bool _isLoading = false;
  final _authService = AuthService();

  File? _diplomaFile;
  bool _isDiplomaUploaded = false;
  final ImagePicker _picker = ImagePicker();
  final Set<String> _allowedExtensions = {
    'pdf',
    'doc',
    'docx',
    'png',
    'jpg',
    'jpeg'
  };

  final _steps = [
    'Cinsiyetinizi seçiniz',
    'Yaşınızı seçiniz',
    'Uzmanlık alanınızı seçiniz',
    'Tecrübe yılınızı giriniz',
    'İletişim bilgilerinizi giriniz',
    'Çalışma yerinizi giriniz',
    'Belgenizi yükleyiniz',
  ];

  final _patientSteps = [
    'Cinsiyetinizi seçiniz',
    'Yaşınızı seçiniz',
    'İletişim bilgilerinizi giriniz',
  ];

  final List<String> _specialities = [
    'Dermatoloji',
    'Dermatopatoloji ',
    'Pediatrik Dermatoloji',
    'Estetik Dermatoloji',
    'Plastik Cerrahi',
  ];

  final _tcNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  final _tcFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();

  bool _isTcFocused = false;
  bool _isPhoneFocused = false;
  bool _isLocationFocused = false;

  @override
  void initState() {
    super.initState();

    _tcFocusNode.addListener(_onTcFocusChange);
    _phoneFocusNode.addListener(_onPhoneFocusChange);
    _locationFocusNode.addListener(_onLocationFocusChange);
  }

  void _onTcFocusChange() {
    setState(() {
      _isTcFocused = _tcFocusNode.hasFocus;
    });
  }

  void _onPhoneFocusChange() {
    setState(() {
      _isPhoneFocused = _phoneFocusNode.hasFocus;
    });
  }

  void _onLocationFocusChange() {
    setState(() {
      _isLocationFocused = _locationFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _tcNumberController.dispose();
    _phoneController.dispose();
    _locationController.dispose();

    _tcFocusNode.removeListener(_onTcFocusChange);
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _locationFocusNode.removeListener(_onLocationFocusChange);

    _tcFocusNode.dispose();
    _phoneFocusNode.dispose();
    _locationFocusNode.dispose();

    super.dispose();
  }

  Widget _buildDoctorForm() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
          ),
          SizedBox(height: 16.0),
          Text(
            _steps[_currentStep],
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: textColor2,
            ),
          ),
          SizedBox(height: 16.0),
          Expanded(
            child: _buildCurrentStep(),
          ),
          SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _currentStep == _steps.length - 1 ? 'Kaydet' : 'Sonraki',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientForm() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / _patientSteps.length,
            backgroundColor: Colors.grey[300],
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          SizedBox(height: 16.0),
          Text(
            _patientSteps[_currentStep],
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: 16.0),
          Expanded(
            child: _buildPatientStep(),
          ),
          SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextPatientStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _currentStep == _patientSteps.length - 1
                          ? 'Kaydet'
                          : 'Sonraki',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildGenderSelection();
      case 1:
        return _buildAgeInput();
      case 2:
        return _buildSpecialitySelection();
      case 3:
        return _buildExperienceInput();
      case 4:
        return _buildContactInfo();
      case 5:
        return _buildLocationInput();
      case 6:
        return _buildDocumentsUpload();
      default:
        return Container();
    }
  }

  Widget _buildPatientStep() {
    switch (_currentStep) {
      case 0:
        return _buildGenderSelection();
      case 1:
        return _buildAgeInput();
      case 2:
        return _buildPatientContactInfo();
      default:
        return Container();
    }
  }

  Widget _buildGenderSelection() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _gender = 0),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: 200,
              decoration: BoxDecoration(
                color: _gender == 0
                    ? Colors.blue.withOpacity(0.10)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _gender == 0 ? Colors.blue : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.male_rounded,
                    color: _gender == 0 ? Colors.blue : Colors.grey,
                    size: 60,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Erkek',
                    style: TextStyle(
                      fontSize: 20,
                      color: _gender == 0 ? Colors.blue : Colors.grey,
                      fontWeight:
                          _gender == 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _gender = 1),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: 200,
              decoration: BoxDecoration(
                color: _gender == 1
                    ? Colors.pink.withOpacity(0.10)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _gender == 1 ? Colors.pink : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.female_rounded,
                    color: _gender == 1 ? Colors.pink : Colors.grey,
                    size: 60,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Kadın',
                    style: TextStyle(
                      fontSize: 20,
                      color: _gender == 1 ? Colors.pink : Colors.grey,
                      fontWeight:
                          _gender == 1 ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildAgeInput() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 250,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                textColor1.withOpacity(0.250),
                textColor1,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: textColor1.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_age',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'yaş',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 40),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: secondaryColor,
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Colors.white,
            overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
            trackHeight: 8.0,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 15.0),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 25.0),
          ),
          child: Slider(
            value: _age.toDouble(),
            min: 25,
            max: 80,
            divisions: 55,
            onChanged: (value) {
              setState(() => _age = value.toInt());
              HapticFeedback.lightImpact();
            },
          ),
        ),
        SizedBox(height: 16),
        Text(
          '25 - 80 yaş arası',
          style: TextStyle(
            color: primaryColorLight,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialitySelection() {
    return GridView.builder(
      padding: EdgeInsets.symmetric(vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: _specialities.length,
      itemBuilder: (context, index) {
        final specialty = _specialities[index];
        final isSelected = _speciality == specialty;

        return GestureDetector(
          onTap: () => setState(() => _speciality = specialty),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? textColor1 : Colors.grey[300]!,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medical_services,
                  size: 40,
                  color: isSelected ? textColor1 : Colors.grey[400],
                ),
                SizedBox(height: 12),
                Text(
                  specialty,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? textColor1 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExperienceInput() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                textColor1.withOpacity(0.7),
                textColor1,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: textColor1.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_experience',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'yıl',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 40),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: secondaryColor,
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Colors.white,
            overlayColor: Theme.of(context).primaryColor.withOpacity(0.2),
            trackHeight: 8.0,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 15.0),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 25.0),
          ),
          child: Slider(
            value: _experience.toDouble(),
            min: 0,
            max: 50,
            divisions: 50,
            onChanged: (value) {
              setState(() => _experience = value.toInt());
              HapticFeedback.lightImpact();
            },
          ),
        ),
        SizedBox(height: 16),
        Text(
          '0 - 50 yıl arası',
          style: TextStyle(
            color: primaryColorLight,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo() {
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(45),
          child: Column(
            children: [
              TextField(
                controller: _tcNumberController,
                onChanged: (value) => setState(() => _tcNumber = value),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'T.C. Kimlik Numarası',
                  labelStyle: TextStyle(
                      color: _isTcFocused
                          ? textColor1
                          : textColor1.withOpacity(0.6),
                      fontSize: 16),
                  prefixIcon: Icon(Icons.credit_card, color: textColor1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1.withOpacity(0.4)),
                  ),
                ),
                focusNode: _tcFocusNode,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                onChanged: (value) => setState(
                  () => _phoneNumber = value,
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası',
                  labelStyle: TextStyle(
                      color: _isPhoneFocused
                          ? textColor1
                          : textColor1.withOpacity(0.6),
                      fontSize: 16),
                  prefixIcon: Icon(Icons.phone, color: textColor1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1.withOpacity(0.4)),
                  ),
                ),
                focusNode: _phoneFocusNode,
              ),
            ],
          ),
        ),
        Text(
          'Lütfen geçerli iletişim bilgilerinizi giriniz',
          style: TextStyle(
            color: primaryColorLight,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInput() {
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          child: TextField(
            controller: _locationController,
            onChanged: (value) => setState(() => _location = value),
            textInputAction: TextInputAction.done,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Çalışma Yeri Adresi',
              labelStyle: TextStyle(
                  color: _isLocationFocused
                      ? textColor1
                      : textColor1.withOpacity(0.6),
                  fontSize: 16),
              prefixIcon: Icon(Icons.location_on, color: textColor1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: textColor1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: textColor1, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: textColor1.withOpacity(0.4)),
              ),
              hintText: 'Detaylı adres bilgilerinizi giriniz',
            ),
            focusNode: _locationFocusNode,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Lütfen güncel çalışma yeri adresinizi giriniz',
          style: TextStyle(
            color: primaryColorLight,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientContactInfo() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _tcNumberController,
                onChanged: (value) => setState(() => _tcNumber = value),
                keyboardType: TextInputType.number,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'T.C. Kimlik Numarası',
                  labelStyle: TextStyle(
                      color: _isTcFocused
                          ? textColor1
                          : textColor1.withOpacity(0.6),
                      fontSize: 16),
                  prefixIcon: Icon(Icons.credit_card, color: textColor1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1.withOpacity(0.4)),
                  ),
                ),
                focusNode: _tcFocusNode,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                onChanged: (value) => setState(() => _phoneNumber = value),
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası',
                  labelStyle: TextStyle(
                      color: _isPhoneFocused
                          ? textColor1
                          : textColor1.withOpacity(0.6),
                      fontSize: 16),
                  prefixIcon: Icon(Icons.phone, color: textColor1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor1.withOpacity(0.4)),
                  ),
                ),
                focusNode: _phoneFocusNode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsUpload() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Doktor Belgesi Yükleyin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '* Belge yüklemek zorunludur (pdf, doc, docx, png, jpg, jpeg)',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 20),
          _buildDocumentCard(
            title: 'Belge *',
            description: 'Diploma veya uzmanlık belgenizi yükleyin',
            isUploaded: _isDiplomaUploaded,
            onTap: _pickDiploma,
            fileName: _diplomaFile?.path.split('/').last ?? '',
            isRequired: true,
          ),
          const SizedBox(height: 20),
          Text(
            'Not: Yüklediğiniz belge yönetici onayından sonra geçerli olacaktır.',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String description,
    required bool isUploaded,
    required VoidCallback onTap,
    required String fileName,
    required bool isRequired,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isUploaded
                        ? Colors.green.withOpacity(0.1)
                        : isRequired
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isUploaded
                        ? Icons.check_circle
                        : isRequired
                            ? Icons.warning_amber
                            : Icons.upload_file,
                    color: isUploaded
                        ? Colors.green
                        : isRequired
                            ? Colors.red
                            : textColor1,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isUploaded ? 'Dosya yüklendi: $fileName' : description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isUploaded
                              ? Colors.green
                              : isRequired && !isUploaded
                                  ? Colors.red
                                  : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDiploma() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        // Dosya uzantısını kontrol et
        final String extension =
            path.extension(pickedFile.path).toLowerCase().replaceAll('.', '');

        if (!_allowedExtensions.contains(extension)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Geçersiz dosya formatı. Kabul edilen formatlar: pdf, doc, docx, png, jpg, jpeg')));
          return;
        }

        setState(() {
          _diplomaFile = File(pickedFile.path);
          _isDiplomaUploaded = true;
        });

        // Dosya boyutu kontrolü
        final fileSize = await _diplomaFile!.length();
        final fileSizeInMB = fileSize / (1024 * 1024);

        if (fileSizeInMB > 5) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Dosya boyutu çok büyük. Maksimum 5MB izin verilir.')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya seçilirken bir hata oluştu: $e')),
      );
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);

    try {
      final String? documentPath = _diplomaFile?.path;

      final result = await _authService.completeSignUp(
        tcid: _tcNumber,
        phone: _phoneNumber,
        age: _age,
        gender: _gender == 0 ? 'Male' : 'Female',
        experience: "$_experience years",
        expert: _speciality,
        clinic: _location,
        diplomaPath: documentPath,
        specialtyPath: null,
      );

      setState(() => _isLoading = false);

      if (result['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt işlemi başarısız: $e')),
      );
    }
  }

  void _nextStep() async {
    // Belge yükleme adımındaysa ve diploma yüklenmemişse uyarı ver
    if (_currentStep == 6 && !_isDiplomaUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belge yüklemek zorunludur!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      await _handleRegister();
    }
  }

  void _nextPatientStep() async {
    if (_currentStep < _patientSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      await _handleRegister();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.userType == 'doctor' ? 'Doktor Profili' : 'Hasta Profili'),
        titleTextStyle: TextStyle(
          color: textColor1,
          fontSize: 23,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: widget.userType == 'doctor'
          ? _buildDoctorForm()
          : _buildPatientForm(),
    );
  }
}
