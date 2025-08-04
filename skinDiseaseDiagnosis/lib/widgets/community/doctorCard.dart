import 'package:flutter/material.dart';
import '../../style/color.dart';
import '../community/create_post_button.dart';

class DoctorCard extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final Function(Map<String, dynamic>) onTap;

  const DoctorCard({
    Key? key,
    required this.doctor,
    required this.onTap,
  }) : super(key: key);

  @override
  State<DoctorCard> createState() => _DoctorCardState();
}

class _DoctorCardState extends State<DoctorCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final doctorId = widget.doctor['id']?.toString() ?? '';
    final doctorName =
        '${widget.doctor['name'] ?? ''} ${widget.doctor['surname'] ?? ''}';
    final specialty =
        widget.doctor['expert'] ?? widget.doctor['specialty'] ?? 'Uzman Doktor';
    final email = widget.doctor['email'] ?? '';
    final phone = widget.doctor['phone'] ?? '';
    final experience = widget.doctor['experience'] ?? 'Belirtilmemiş';
    final clinic = widget.doctor['clinic'] ?? 'Belirtilmemiş';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor,
              isExpanded
                  ? secondaryColorLight.withOpacity(0.2)
                  : secondaryColorLight.withOpacity(0.1),
            ],
          ),
        ),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() {
              isExpanded = expanded;
            });
          },
          tilePadding: EdgeInsets.all(12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              _buildDoctorAvatar(doctorName),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. $doctorName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        specialty,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Divider(color: Colors.grey.withOpacity(0.2)),
            _buildInfoRow(Icons.email_outlined, 'E-posta', email),
            _buildInfoRow(Icons.phone_outlined, 'Telefon', phone),
            _buildInfoRow(Icons.work_outline, 'Deneyim', experience),
            _buildInfoRow(Icons.local_hospital_outlined, 'Klinik', clinic),
            SizedBox(height: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: secondaryColor),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorAvatar(String doctorName) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [secondaryColor, secondaryColorLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: secondaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => widget.onTap(widget.doctor),
            icon: Icon(Icons.chat_bubble_outline, size: 16),
            label: Text(
              'Mesaj Gönder',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: secondaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EmptyDoctorsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Henüz doktor bulunamadı',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          // You could optionally add a create post button here if you want
          // SizedBox(height: 32),
          // ElevatedButton.icon(
          //   onPressed: () => CreatePostHelper.navigateToCreatePost(context),
          //   icon: Icon(Icons.add),
          //   label: Text('Gönderi Oluştur'),
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: primaryColor,
          //     foregroundColor: Colors.white,
          //   ),
          // ),
        ],
      ),
    );
  }
}
