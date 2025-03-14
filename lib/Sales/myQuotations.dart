import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'Views/pipeLineView.dart';
import 'Views/quotationsView.dart';
import 'myPipeline.dart';

class Myquotations extends StatefulWidget {
  const Myquotations({super.key});

  @override
  State<Myquotations> createState() => _MyquotationsState();
}

class _MyquotationsState extends State<Myquotations> {
  int? currentUserId;
  int selectedView = 0;
  OdooClient? client;
  bool isLoading = true;
  List<ChartData> chartDatavalues = [];
  String selectedChart = "bar";
  bool showNoDataMessage = false;
  List<Map<String, dynamic>> leadsList = [];
  List<Map<String, dynamic>> opportunitiesList = [];
  Uint8List? profileImage;
  List<String> activityTypes = [];
  List<Map<String, dynamic>> activitiesList = [];

  @override
  void initState() {
    super.initState();
    initializeOdooClient();
  }

  Future<void> initializeOdooClient() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString("urldata") ?? "";
    final dbName = prefs.getString("selectedDatabase") ?? "";
    final userLogin = prefs.getString("userLogin") ?? "";
    final userPassword = prefs.getString("password") ?? "";
    currentUserId = prefs.getInt("userId");

    if (baseUrl.isNotEmpty &&
        dbName.isNotEmpty &&
        userLogin.isNotEmpty &&
        userPassword.isNotEmpty) {
      client = OdooClient(baseUrl);
      try {
        final auth =
            await client!.authenticate(dbName, userLogin, userPassword);
        print("Odoo Authenticated: $auth");
        await userImage();
        await fetchLeadsData();
        await tag();
        await act();
      } catch (e) {
        print("Odoo Authentication Failed: $e");
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> fetchLeadsData() async {
    if (client == null || currentUserId == null) {
      print("Client or user ID is null");
      return;
    }

    try {
      final response = await client?.callKw({
        'model': 'sale.order',
        'method': 'search_read',
        'args': [
          [
            ["user_id", "=", currentUserId]
          ]
        ],
        'kwargs': {
          'fields': [
            'name',
            'partner_id',
            'create_date',
            'user_id',
            'company_id',
            'amount_total',
            'state',
            'activity_type_id',
            'activity_summary',
            'activity_date_deadline',
            'date_order',
          ],
        }
      });

      log("Leads fetched: ${response}");

      if (response != null) {
        setState(() {
          leadsList = List<Map<String, dynamic>>.from(response);
          opportunitiesList =
              leadsList.where((lead) => lead['type'] == "opportunity").toList();
          chartDatavalues = prepareChartData(leadsList);
          showNoDataMessage = chartDatavalues.isEmpty;
        });

        print("Leads list updated with ${leadsList.length} items");
      }
    } catch (e) {
      print("Failed to fetch leads: $e");
    }
  }

  Widget ChartSelection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey.shade200,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 0;
                  });
                },
                icon: Icon(
                  Icons.bar_chart_rounded,
                  color: selectedView == 0 ? Color(0xFF9EA700) : Colors.black,
                ),
              ),
              VerticalDivider(thickness: 2, color: Colors.white),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 1;
                  });
                },
                icon: Icon(
                  Icons.view_list_rounded,
                  color: selectedView == 1 ? Color(0xFF9EA700) : Colors.black,
                ),
              ),
              VerticalDivider(thickness: 2, color: Colors.white),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 2;
                  });
                },
                icon: Icon(
                  Icons.calendar_month,
                  color: selectedView == 2 ? Color(0xFF9EA700) : Colors.black,
                ),
              ),
              VerticalDivider(thickness: 2, color: Colors.white),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 3;
                  });
                },
                icon: Icon(
                  Icons.table_rows_outlined,
                  color: selectedView == 3 ? Color(0xFF9EA700) : Colors.black,
                ),
              ),
              VerticalDivider(thickness: 2, color: Colors.white),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 4;
                  });
                },
                icon: Icon(
                  Icons.graphic_eq_rounded,
                  color: selectedView == 4 ? Color(0xFF9EA700) : Colors.black,
                ),
              ),
              VerticalDivider(thickness: 2, color: Colors.white),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 5;
                  });
                },
                icon: Icon(
                  Icons.access_time,
                  color: selectedView == 5 ? Color(0xFF9EA700) : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<int, String>> tag() async {
    Map<int, String> tagMap = {};
    try {
      final response = await client?.callKw({
        'model': 'crm.tag',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name', 'color'],
        }
      });
      print('Tags response: $response');
      if (response != null) {
        for (var tag in response) {
          tagMap[tag['id']] = tag['name'];
        }
      }
      print('Tags fetched: $tagMap');
      return tagMap;
    } catch (e) {
      print("Failed to fetch tags: $e");
      return {};
    }
  }

  Future<void> act() async {
    try {
      final response = await client?.callKw({
        'model': 'mail.activity.type',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': [
            'name',
          ],
        }
      });

      print('Activity types: $response');

      if (response != null && response is List) {
        setState(() {
          activityTypes =
              response.map((item) => item['name'].toString()).toList();
        });
      }
    } catch (e) {
      print("Failed to fetch activity types: $e");
    }
  }

  Future<void> userImage() async {
    final prefs = await SharedPreferences.getInstance();
    final userid = prefs.getInt("userId") ?? "";
    try {
      final response = await client?.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ["id", "=", userid],
          ]
        ],
        'kwargs': {
          'fields': [
            'image_1920',
            'name',
          ]
        },
      });
      print('User image response: $response');
      if (response == null || response.isEmpty || response is! List) {
        print('No data received or invalid format');
        return;
      }
      try {
        final List<Map<String, dynamic>> data =
            List<Map<String, dynamic>>.from(response);
        setState(() {
          var imageData = data[0]['image_1920'];
          if (imageData != null && imageData is String) {
            profileImage = base64Decode(imageData);
            print('Profile image decoded, length: ${profileImage?.length}');
          }
        });
      } catch (e) {
        print("Error processing image data: $e");
      }
    } catch (e) {
      print("Error fetching user image: $e");
    }
  }

  Widget listCard() {
    print('List card rendering with ${leadsList.length} leads');

    if (isLoading) {
      return Center(
        child: LoadingAnimationWidget.fourRotatingDots(
          color: Color(0xFF9EA700),
          size: 100,
        ),
      );
    }

    if (leadsList.isEmpty) {
      return Center(
        child: Text(
          "No leads found",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: leadsList.length,
      padding: EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final lead = leadsList[index];
        final leadId = lead['id'];
        final name = lead['name'] ?? '';
        final creationDate = lead['create_date'] != null
            ? DateFormat('MM/dd/yyyy')
                .format(DateTime.parse(lead['create_date']))
            : '';
        final partnerId = lead['partner_id'];
        final customerName =
            (partnerId is List && partnerId.length > 1) ? partnerId[1] : 'None';
        final email = lead['email_from'] ?? 'None';
        lead['stage_id'] is List && lead['stage_id'].length > 1
            ? lead['stage_id'][1]
            : "None";
        final company = lead['company_id'] != null &&
                lead['company_id'] is List &&
                lead['company_id'].length > 1
            ? lead['company_id'][1]
            : "";
        final salesperson = lead['user_id'] != null &&
                lead['user_id'] is List &&
                lead['user_id'].length > 1
            ? lead['user_id'][1]
            : "None";
        final hasActivity = lead['activity_type_id'] != null &&
            lead['activity_type_id'] is List &&
            lead['activity_type_id'].isNotEmpty;
        final activityType = hasActivity && lead['activity_type_id'].length > 1
            ? lead['activity_type_id'][1].toString().toLowerCase()
            : 'none';
        final activitySummary = lead['activity_summary']?.toString() ?? '';
        final total = lead['amount_total']?.toString() ?? '0.0';
        final rawStatus = lead['state']?.toString().toLowerCase() ?? 'draft';

        String status;
        Color statusColor;
        switch (rawStatus) {
          case 'sent':
            status = 'Quotation Sent';
            statusColor = Colors.yellow.shade700;
            break;
          case 'sale':
            status = 'Sales Order';
            statusColor = Colors.green.shade600;
            break;
          case 'draft':
          default:
            status = 'Quotation';
            statusColor = Colors.grey.shade600;
            break;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuotationPage(quotationId: leadId),
              ),
            );
          },
          child: Card(
            color: Colors.white,
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(0xFF9EA700),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Color(0xFF9EA700).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2))
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(
                        height: 24, thickness: 1, color: Colors.grey.shade200),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contact',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  customerName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                email != 'None'
                                    ? Row(
                                        children: [
                                          Icon(Icons.email_outlined,
                                              size: 14, color: Colors.blue),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              email,
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : SizedBox(),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Creation Date',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  creationDate,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined,
                                        size: 14,
                                        color: Colors.orange.shade700),
                                    SizedBox(width: 4),
                                    Text(
                                      'Date & Time',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Second row: Company and Salesperson
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Company',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  company,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.business_outlined,
                                        size: 14, color: Colors.teal),
                                    SizedBox(width: 4),
                                    Text(
                                      'Organization',
                                      style: TextStyle(
                                        color: Colors.teal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Salesperson',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    profileImage != null
                                        ? Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                              image: DecorationImage(
                                                image:
                                                    MemoryImage(profileImage!),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue.shade700,
                                                  Colors.blue.shade500
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.blue
                                                      .withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(Icons.person,
                                                size: 16, color: Colors.white),
                                          ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        salesperson,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Third row: Total, Status, and Activity
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total and Status container
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Total
                                Row(
                                  children: [
                                    Text(
                                      'Total: ',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '\$$total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF9EA700),
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // Status
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Activity container
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: hasActivity
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: hasActivity
                                    ? Colors.blue.shade200
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: hasActivity
                                        ? Colors.blue.shade100
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    getActivityIcon(activityType),
                                    size: 18,
                                    color: hasActivity
                                        ? Colors.blue.shade600
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Activity',
                                        style: TextStyle(
                                          color: hasActivity
                                              ? Colors.blue.shade700
                                              : Colors.grey.shade600,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        hasActivity
                                            ? (activitySummary != 'false'
                                                ? activitySummary
                                                : activityType.toUpperCase())
                                            : 'No Activity',
                                        style: TextStyle(
                                          color: hasActivity
                                              ? Colors.blue.shade800
                                              : Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'todo':
      case 'task':
        return Icons.check_circle_outline;
      case 'call':
        return Icons.phone_outlined;
      case 'meeting':
        return Icons.people_outline;
      case 'email':
        return Icons.email_outlined;
      case 'none':
        return Icons.event_busy;
      default:
        return Icons.event_available;
    }
  }

  Widget salesListCard() {
    print('Sales card rendering with ${leadsList.length} records');

    if (isLoading) {
      return Center(
        child: LoadingAnimationWidget.fourRotatingDots(
          color: Color(0xFF9EA700),
          size: 100,
        ),
      );
    }

    if (leadsList.isEmpty) {
      return Center(
        child: Text(
          "No sales records found",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: leadsList.length,
      padding: EdgeInsets.all(8),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final lead = leadsList[index];
        final name = lead['name'] ?? '';
        final partnerId = lead['partner_id'];
        final customerName =
            (partnerId is List && partnerId.length > 1) ? partnerId[1] : 'None';
        final total = lead['amount_total']?.toString() ?? '0.0';
        final String orderNumber = lead['order_number'] ?? '';
        final creationDate = lead['create_date'] != null
            ? DateFormat('MM/dd/yyyy')
                .format(DateTime.parse(lead['create_date']))
            : '';
        final hasActivity = lead['activity_type_id'] != null &&
            lead['activity_type_id'] is List &&
            lead['activity_type_id'].isNotEmpty;
        final activityType = hasActivity && lead['activity_type_id'].length > 1
            ? lead['activity_type_id'][1].toString().toLowerCase()
            : 'none';
        final activitySummary = lead['activity_summary']?.toString() ?? '';
        final rawStatus = lead['state']?.toString().toLowerCase() ?? 'draft';
        Color activityIconColor = Colors.grey;
        if (lead['activity_date_deadline'] != false) {
          DateTime deadline = DateTime.parse(lead['activity_date_deadline']);
          DateTime today = DateTime.now();

          if (deadline.isBefore(today)) {
            activityIconColor = Colors.red;
          } else {
            activityIconColor = Colors.green;
          }
        }

        String status;
        Color statusColor;
        switch (rawStatus) {
          case 'sent':
            status = 'Quotation Sent';
            statusColor = Colors.yellow.shade700;
            break;
          case 'sale':
            status = 'Sales Order';
            statusColor = Colors.green.shade600;
            break;
          case 'draft':
          default:
            status = 'Quotation';
            statusColor = Colors.grey.shade600;
            break;
        }

        IconData activityIcon;
        switch (activityType.toLowerCase()) {
          case 'email':
            activityIcon = Icons.email;
            break;
          case 'call':
            activityIcon = Icons.phone;
            break;
          case 'meeting':
            activityIcon = Icons.event;
            break;
          case 'to-do':
            activityIcon = Icons.dashboard;
            break;
          case 'upload document':
            activityIcon = Icons.upload_file;
            break;
          case 'exception':
            activityIcon = Icons.warning;
            break;
          case 'follow-up quote':
            activityIcon = Icons.refresh;
            break;
          case 'make quote':
            activityIcon = Icons.description;
            break;
          case 'call for demo':
            activityIcon = Icons.video_call;
            break;
          case 'email: welcome demo':
            activityIcon = Icons.celebration;
            break;
          case 'order upsell':
            activityIcon = Icons.stacked_line_chart_rounded;
            break;
          default:
            activityIcon = Icons.access_time;
            break;
        }

        return Card(
          color: Colors.white,
          margin: EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () {
              print('Tapped');
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$ ${total}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      // Order number
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        creationDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(activityIcon, size: 16, color: activityIconColor),

                      Spacer(),

                      // Status indicator
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: statusColor,
                          ),
                          SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 14,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget calendarView() {
    List<Appointment> appointments = [];
    Map<String, Map<String, dynamic>> appointmentLeadMap = {};

    for (var lead in leadsList) {
      if (lead['activity_date_deadline'] != null &&
          lead['activity_date_deadline'] != false) {
        DateTime deadlineDate;
        try {
          if (lead['activity_date_deadline'] is String) {
            deadlineDate = DateTime.parse(lead['activity_date_deadline']);
          } else {
            deadlineDate = lead['activity_date_deadline'];
          }

          String appointmentId = "${lead['id']}_${deadlineDate.toString()}";

          appointments.add(
            Appointment(
              startTime: deadlineDate,
              endTime: deadlineDate.add(Duration(hours: 1)),
              subject: lead['name'] ?? 'No Title',
              color: Color(0xFF9EA700),
              isAllDay: true,
              id: appointmentId,
            ),
          );
          appointmentLeadMap[appointmentId] = lead;
        } catch (e) {
          print('Error parsing deadline date: $e');
        }
      }
    }

    return Container(
      child: SfCalendar(
        view: CalendarView.month,
        headerStyle: CalendarHeaderStyle(backgroundColor: Color(0x69EA700)),
        dataSource: AppointmentDataSource(appointments),
        monthViewSettings: MonthViewSettings(
          showAgenda: true,
          agendaViewHeight: 200,
          appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
        ),
        todayHighlightColor: Color(0xFF9EA700),
        selectionDecoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Color(0xFF9EA700), width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          shape: BoxShape.rectangle,
        ),
        onTap: (CalendarTapDetails details) {
          if (details.targetElement == CalendarElement.appointment) {
            Appointment appointment = details.appointments![0];
            String appointmentId = appointment.id.toString();

            if (appointmentLeadMap.containsKey(appointmentId)) {
              calendarDialogue(context, appointmentLeadMap[appointmentId]!);
            }
          }
        },
      ),
    );
  }

  void calendarDialogue(BuildContext context, Map<String, dynamic> lead) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Activity Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF9EA700),
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  lead['name'] ?? 'None ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Expected Revenue',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '\$${lead['amount_total']?.toString() ?? '0.00'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF9EA700),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Customer',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  lead['partner_id'] != null &&
                          lead['partner_id'] is List &&
                          lead['partner_id'].length > 1
                      ? lead['partner_id'][1]
                      : 'None',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Activity Deadline',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  lead['activity_date_deadline'] != null &&
                          lead['activity_date_deadline'] != false
                      ? lead['activity_date_deadline'] is DateTime
                          ? lead['activity_date_deadline']
                              .toString()
                              .split(' ')[0]
                          : lead['activity_date_deadline'].toString()
                      : 'No deadline',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        lead['activity_state'] == 'overdue' ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.edit, size: 16, color: Colors.black),
                  label: Text('Edit'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Color(0xFF9EA700),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.delete, size: 16, color: Colors.black),
                  label: Text('Delete'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Color(0xFF9EA700),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget fetchData() {
    if (leadsList.isEmpty) {
      return Center(child: Text("No data available"));
    }

    Set<String> uniqueStages = {};
    Map<String, Map<String, dynamic>> groupedData = {};
    Map<String, double> columnTotals = {};
    uniqueStages.add('total');

    for (var lead in leadsList) {
      String dateOrder = lead['date_order']?.toString() ?? "None";

      String monthYear = "None";
      if (dateOrder != "None") {
        try {
          DateTime dateTime = DateTime.parse(dateOrder);
          monthYear = formatMonthYear(dateTime);
        } catch (e) {
          print('Error parsing date: $e');
          monthYear = "Unknown Month";
        }
      }

      double revenue =
          double.tryParse(lead['amount_total']?.toString() ?? "0") ?? 0.0;

      if (!groupedData.containsKey(monthYear)) {
        groupedData[monthYear] = {'date': monthYear};
      }

      if (!groupedData[monthYear]!.containsKey('total')) {
        groupedData[monthYear]!['total'] = "0";
      }

      double currentTotal =
          double.tryParse(groupedData[monthYear]!['total']) ?? 0.0;
      groupedData[monthYear]!['total'] =
          (currentTotal + revenue).toStringAsFixed(2);

      columnTotals['total'] = (columnTotals['total'] ?? 0.0) + revenue;
    }

    List<GridColumn> columns = [
      GridColumn(
        columnName: 'date',
        label: Container(
          alignment: Alignment.center,
          child: Text(
            'Month',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      ...uniqueStages.map(
        (stage) => GridColumn(
          columnName: stage,
          label: Container(
            alignment: Alignment.center,
            child: Text(
              stage.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ];

    List<DataGridRow> rows = groupedData.entries.map((entry) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(columnName: 'date', value: entry.value['date']),
          ...uniqueStages.map(
            (stage) => DataGridCell<String>(
              columnName: stage,
              value: entry.value[stage] ?? "0",
            ),
          ),
        ],
      );
    }).toList();

    // Add total row
    rows.add(DataGridRow(
      cells: [
        DataGridCell<String>(columnName: 'date', value: "Total"),
        ...uniqueStages.map(
          (stage) => DataGridCell<String>(
            columnName: stage,
            value: columnTotals[stage]?.toStringAsFixed(2) ?? "0",
          ),
        ),
      ],
    ));

    return SfDataGrid(
      source: tableSource(rows),
      columns: columns,
      columnWidthMode: ColumnWidthMode.fill,
    );
  }

  String formatMonthYear(DateTime dateTime) {
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    String month = months[dateTime.month - 1];
    return "$month ${dateTime.year}";
  }

  Widget buildChart() {
    if (selectedChart == "bar") {
      return showNoDataMessage
          ? Column(
              children: [
                Center(child: Image.asset('assets/nodata.png')),
                Text(
                  "No data to display",
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ],
            )
          : SfCartesianChart(
              margin: EdgeInsets.all(10),
              primaryXAxis: CategoryAxis(
                labelIntersectAction: AxisLabelIntersectAction.rotate45,
                labelStyle: TextStyle(fontSize: 10),
                maximumLabels: 100,
                labelPlacement: LabelPlacement.onTicks,
                interval: 1.2,
              ),
              series: <CartesianSeries<ChartData, String>>[
                ColumnSeries<ChartData, String>(
                  dataSource: chartDatavalues,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  color: Color(0xFF9EA700),
                ),
              ],
            );
    } else if (selectedChart == "line") {
      return showNoDataMessage
          ? Column(
              children: [
                Center(child: Image.asset('assets/nodata.png')),
                Text(
                  "No data to display",
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ],
            )
          : SfCartesianChart(
              margin: EdgeInsets.all(10),
              primaryXAxis: CategoryAxis(
                labelIntersectAction: AxisLabelIntersectAction.rotate45,
                labelStyle: TextStyle(fontSize: 10),
                maximumLabels: 100,
                labelPlacement: LabelPlacement.onTicks,
                majorGridLines: MajorGridLines(width: 0),
              ),
              series: <CartesianSeries<ChartData, String>>[
                LineSeries<ChartData, String>(
                  dataSource: chartDatavalues,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  color: Color(0xFF9EA700),
                ),
              ],
            );
    } else {
      return showNoDataMessage
          ? Column(
              children: [
                Center(child: Image.asset('assets/nodata.png')),
                Text(
                  "No data to display",
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ],
            )
          : SfCircularChart(
              margin: EdgeInsets.all(10),
              legend: Legend(
                isVisible: true,
                overflowMode: LegendItemOverflowMode.wrap,
                position: LegendPosition.bottom,
              ),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CircularSeries<ChartData, String>>[
                PieSeries<ChartData, String>(
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    labelPosition: ChartDataLabelPosition.outside,
                    connectorLineSettings: ConnectorLineSettings(
                      type: ConnectorType.line,
                      length: '15%',
                    ),
                  ),
                  explode: true,
                  dataSource: chartDatavalues,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                ),
              ],
            );
    }
  }

  List<ChartData> prepareChartData(List<Map<String, dynamic>> salesOrders) {
    if (salesOrders.isEmpty) {
      return [];
    }
    Map<String, double> customerSales = {};

    for (var order in salesOrders) {
      String customerName = "";
      double amount = 0.0;

      if (order['partner_id'] != false &&
          order['partner_id'] is List &&
          order['partner_id'].length > 1) {
        customerName = order['partner_id'][1].toString();
      } else {
        customerName = "Unknown";
      }
      if (order['amount_total'] != false) {
        amount = double.tryParse(order['amount_total'].toString()) ?? 0.0;
      }

      if (customerSales.containsKey(customerName)) {
        customerSales[customerName] = customerSales[customerName]! + amount;
      } else {
        customerSales[customerName] = amount;
      }
    }

    List<ChartData> chartData = customerSales.entries.map((entry) {
      return ChartData(entry.key, entry.value);
    }).toList();

    // Sort the list based on x value (customer name)
    chartData.sort((a, b) => a.x.compareTo(b.x));

    return chartData;
  }

  Widget buildChartSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 10,
          ),
          child: Container(
            width: 105,
            height: 30,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Color(0xFF9EA700),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text('Measures'),
                  ),
                  Expanded(
                      child: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                  )),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 150,
        ),
        Container(
          height: 37,
          width: 37,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7), color: Color(0x279EA700)),
          child: IconButton(
              onPressed: () => changeChartType("bar"),
              icon: Icon(Icons.bar_chart_rounded,
                  color: selectedChart == 'bar'
                      ? Color(0xFF9EA700)
                      : Colors.black)),
        ),
        SizedBox(
          width: 5,
        ),
        Container(
          height: 37,
          width: 37,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7), color: Color(0x279EA700)),
          child: IconButton(
              onPressed: () => changeChartType("line"),
              icon: Icon(Icons.stacked_line_chart_rounded,
                  color: selectedChart == 'line'
                      ? Color(0xFF9EA700)
                      : Colors.black)),
        ),
        SizedBox(
          width: 5,
        ),
        Padding(
          padding: EdgeInsets.only(right: 6),
          child: Container(
            height: 37,
            width: 37,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: Color(0x279EA700)),
            child: IconButton(
                onPressed: () => changeChartType("pie"),
                icon: Icon(Icons.pie_chart_rounded,
                    color: selectedChart == 'pie'
                        ? Color(0xFF9EA700)
                        : Colors.black)),
          ),
        ),
      ],
    );
  }

  void changeChartType(String type) {
    setState(() {
      selectedChart = type;
    });
  }

  Widget iconSelectedView() {
    switch (selectedView) {
      case 0:
        return listCard();
      case 1:
        return salesListCard();
      case 2:
        return calendarView();
      case 3:
        return fetchData();
      case 4:
        return buildChart();
      case 5:
        return buildDataGrid();
      default:
        return Container();
    }
  }

  Widget buildDataGrid() {
    if (isLoading) {
      return Center(
        child: LoadingAnimationWidget.fourRotatingDots(
          color: Color(0xFF9EA700),
          size: 100,
        ),
      );
    }

    if (leadsList.isEmpty) {
      return Center(
        child: Text(
          "No quotations found",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    List<Map<String, dynamic>> filteredQuotations = leadsList
        .where((quotation) =>
            quotation['activity_type_id'] != null &&
            quotation['activity_type_id'] is List &&
            quotation['activity_type_id'].length > 1)
        .toList();

    return SfDataGrid(
      rowHeight: 60,
      source:
          QuotationsDataSource(filteredQuotations, activityTypes, profileImage),
      columnWidthMode: ColumnWidthMode.fill,
      gridLinesVisibility: GridLinesVisibility.both,
      headerGridLinesVisibility: GridLinesVisibility.both,
      columns: getColumns(),
    );
  }

  List<GridColumn> getColumns() {
    List<GridColumn> columns = [
      GridColumn(
        columnName: 'quotation',
        label: Container(
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          child: const Text(
            'Quotation',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        width: 300,
      ),
    ];

    for (var activityType in activityTypes) {
      columns.add(
        GridColumn(
          columnName: activityType,
          label: Container(
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            child: Text(
              activityType,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          width: 120,
        ),
      );
    }

    return columns;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF9EA700),
        title: Text('Quotations'),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.search_rounded)),
          SizedBox(width: 4),
          IconButton(
              onPressed: () {
                // showFilterDialog(context);
              },
              icon: Icon(Icons.filter_list_sharp)),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Divider(thickness: 2, color: Colors.grey.shade300),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quotations',
                  style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
                ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                      foregroundColor: Color(0xFF9EA700),
                    ),
                    child: Text(
                      'New Activity',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    )),
              ],
            ),
          ),
          Divider(thickness: 1, color: Colors.grey.shade300),
          ChartSelection(),
          Divider(thickness: 1, color: Colors.grey.shade300),
          selectedView == 4 ? buildChartSelection() : SizedBox(),
          SizedBox(
            height: 7,
          ),
          Expanded(child: iconSelectedView()),
        ],
      ),
    );
  }
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}

class tableSource extends DataGridSource {
  List<DataGridRow> dataGridRows;

  tableSource(this.dataGridRows);

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    bool isTotalRow = row.getCells().first.value == "Total";
    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(8.0),
          color: isTotalRow ? Colors.grey[300] : null,
          child: Text(cell.value.toString()),
        );
      }).toList(),
    );
  }
}

class ChartData {
  ChartData(this.x, this.y);

  final String x;
  final double y;
}

class QuotationsDataSource extends DataGridSource {
  List<DataGridRow> dataGridRows = [];
  final List<String> activityTypes;
  final Uint8List? currentUserImage;

  QuotationsDataSource(List<Map<String, dynamic>> quotationsList,
      this.activityTypes, this.currentUserImage) {
    dataGridRows = quotationsList.map<DataGridRow>((quotation) {
      Map<String, dynamic> quotationData = {
        'name': quotation['name'] ?? 'None',
        'amount_total': quotation['amount_total'] != null
            ? '\$${quotation['amount_total'].toString()}'
            : '\$0',
        'state': quotation['state']?.toString().toLowerCase() ?? 'draft',
        'partner_id':
            quotation['partner_id'] != null && quotation['partner_id'] is List
                ? quotation['partner_id'][1].toString()
                : 'None',
      };

      for (var type in activityTypes) {
        quotationData[type] = '';
      }
      if (quotation['activity_type_id'] != null &&
          quotation['activity_type_id'] is List &&
          quotation['activity_type_id'].length > 1) {
        String activityType = quotation['activity_type_id'][1].toString();
        if (activityTypes.contains(activityType)) {
          quotationData[activityType] =
              quotation['activity_date_deadline'] ?? '';
        }
      }

      List<DataGridCell> cells = [];
      cells.add(DataGridCell<Map<String, dynamic>>(
        columnName: 'quotation',
        value: quotationData,
      ));

      for (var activityType in activityTypes) {
        cells.add(
          DataGridCell<String>(
            columnName: activityType,
            value: quotationData[activityType],
          ),
        );
      }

      return DataGridRow(cells: cells);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataCell) {
        if (dataCell.columnName == 'quotation') {
          final quotationData = dataCell.value as Map<String, dynamic>;
          return buildQuotationColumn(quotationData);
        }

        String activityDate = dataCell.value.toString();
        DateTime? parsedDate =
            activityDate.isNotEmpty ? DateTime.tryParse(activityDate) : null;
        DateTime today = DateTime.now();

        Color cellColor = Colors.transparent;
        if (parsedDate != null) {
          cellColor = parsedDate.isBefore(today) ? Colors.red : Colors.green;
        }

        bool hasActivity = parsedDate != null && currentUserImage != null;

        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(8),
          color: cellColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dataCell.value.toString(),
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
              if (hasActivity) ...[
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    image: DecorationImage(
                      image: MemoryImage(currentUserImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildQuotationColumn(Map<String, dynamic> quotationData) {
    String status;
    Color statusColor;
    switch (quotationData['state']) {
      case 'sent':
        status = 'Quotation Sent';
        statusColor = Colors.yellow.shade700;
        break;
      case 'sale':
        status = 'Sales Order';
        statusColor = Colors.green.shade600;
        break;
      case 'draft':
      default:
        status = 'Quotation';
        statusColor = Colors.grey.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      quotationData['name'],
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Text(
                        quotationData['amount_total'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      quotationData['partner_id'],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                      child: Container(
                        height: 25,
                        width: 80,
                        color: Colors.grey.shade300,
                        padding: const EdgeInsets.all(5),
                        child: Center(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
