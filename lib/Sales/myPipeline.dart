import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class Mypipeline extends StatefulWidget {
  const Mypipeline({super.key});

  @override
  State<Mypipeline> createState() => _MypipelineState();
}

OdooClient? client;
bool isLoading = true;
final AppFlowyBoardController controller = AppFlowyBoardController();
late AppFlowyBoardScrollController boardController;
int selectedView = 0;
List<Map<String, dynamic>> leadsList = [];

class _MypipelineState extends State<Mypipeline> {
  Uint8List? profileImage;
  String? userName;

  Future<void> initializeOdooClient() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString("urldata") ?? "";
    final dbName = prefs.getString("selectedDatabase") ?? "";
    final userLogin = prefs.getString("userLogin") ?? "";
    final userPassword = prefs.getString("password") ?? "";

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
        await pipe();
        await tag();
        await iconSelectedView();
        // await processTableData();
        // await buildTableView();
        await fetchData();

      } catch (e) {
        print("Odoo Authentication Failed: $e");
      }
    }
    setState(() => isLoading = false);
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
      print('lolkoko$response');
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
      print('imggg$response');
      if (response == null || response.isEmpty || response is! List) {
        print('No data received or invalid format');
        setState(() => isLoading = false);
        return;
      }
      try {
        final List<Map<String, dynamic>> data =
            List<Map<String, dynamic>>.from(response);
        setState(() {
          var imageData = data[0]['image_1920'];
          if (imageData != null && imageData is String) {
            profileImage = base64Decode(imageData);
            print('imageeeeee$profileImage');
          }

          userName = data[0]['name'] ?? '';
        });
      } catch (e) {
        print("Odoo error$e");
      }
    } catch (e) {
      print("Image error$e");
    }
  }

  Future<void> pipe() async {
    final prefs = await SharedPreferences.getInstance();
    final userid = prefs.getInt("userId") ?? "";
    print('iddddd$userid');
    try {
      Map<int, String> tagMap = await tag();
      final response = await client?.callKw({
        'model': 'crm.lead',
        'method': 'search_read',
        'args': [
          [
            ["type", "=", "opportunity"],
            ["user_id", "=", userid],
          ]
        ],
        'kwargs': {
          'fields': [
            'name',
            'expected_revenue',
            'stage_id',
            'partner_id',
            'tag_ids',
            'priority',
            'activity_state',
            'activity_type_id',
            'email_from',
            'recurring_revenue_monthly',
            'contact_name',
            'activity_ids',
            'activity_date_deadline',
            'create_date'
          ],
        }
      });
      print('ressss$response');
      if (response != null) {
        leadsList = List<Map<String, dynamic>>.from(response);
        // calendarOppurtunity(leadsList);
        Map<String, List<Map<String, dynamic>>> groupedLeads = {};

        for (var lead in response) {
          String stage = lead['stage_id'][1] ?? '';
          List<String> tagNames = [];
          if (lead['tag_ids'] != null && lead['tag_ids'] is List) {
            for (var tagId in lead['tag_ids']) {
              if (tagMap.containsKey(tagId)) {
                tagNames.add(tagMap[tagId]!);
              }
            }
          }
          groupedLeads.putIfAbsent(stage, () => []).add(lead);
        }

        controller.clear();

        for (var entry in groupedLeads.entries) {
          final groupData = AppFlowyGroupData(
            id: entry.key,
            name: entry.key,
            items: entry.value.map((lead) {
              List<String> tagNames = [];
              if (lead['tag_ids'] != null && lead['tag_ids'] is List) {
                for (var tagId in lead['tag_ids']) {
                  if (tagMap.containsKey(tagId)) {
                    tagNames.add(tagMap[tagId]!);
                  }
                }
              }
              return LeadItem(
                name: lead['name'],
                revenue: lead['expected_revenue'].toString(),
                customerName: lead['partner_id'] != null &&
                        lead['partner_id'] is List &&
                        lead['partner_id'].length > 1
                    ? lead['partner_id'][1]
                    : "",
                priority: (lead['priority'] is int)
                    ? lead['priority']
                    : int.tryParse(lead['priority'].toString()) ?? 0,
                tags: tagNames,
                activityState: lead['activity_state'] != null
                    ? (lead['activity_state'] is bool
                        ? (lead['activity_state'] ? "true" : "false")
                        : lead['activity_state'].toString())
                    : '',
                activityType: lead['activity_type_id'] != null &&
                        lead['activity_type_id'] is List &&
                        lead['activity_type_id'].length > 1
                    ? lead['activity_type_id'][1]
                    : "",
                hasActivity: lead['activity_ids'] != null &&
                    lead['activity_ids'] is List &&
                    lead['activity_ids'].isNotEmpty,
                activityIds:
                    lead['activity_ids'] != null && lead['activity_ids'] is List
                        ? List<String>.from(
                            lead['activity_ids'].map((e) => e.toString()))
                        : [],
                imageData:
                    profileImage != null ? base64Encode(profileImage!) : null,
              );
            }).toList(),
          );

          controller.addGroup(groupData);
        }

        setState(() {});
      }
    } catch (e) {
      print("Odoo Fetch Failed: $e");
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
                icon: Icon(Icons.calendar_month,
                  color: selectedView == 2 ? Color(0xFF9EA700) : Colors.black,),
              ),
              VerticalDivider(thickness: 2, color: Colors.white),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 3;
                  });
                },
                icon: Icon(Icons.table_rows_outlined,
                  color: selectedView == 3 ? Color(0xFF9EA700) : Colors.black,),
              ),
              VerticalDivider(thickness: 2, color: Colors.white),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 4;
                  });
                },
                icon: Icon(Icons.graphic_eq_rounded, color: Colors.black),
              ),
              VerticalDivider(thickness: 2, color: Colors.white),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedView = 5;
                  });
                },
                icon: Icon(Icons.access_time, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget listCard() {
    print('ghghghhg$leadsList');
    return leadsList.isEmpty
        ? Center(
            child: Text(
              "No leads found",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: leadsList.length,
            padding: EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final lead = leadsList[index];

              final name = lead['name'] ?? '';
              final revenue = lead['expected_revenue']?.toString() ?? '';
              final customerName = lead['contact_name'] == false
                  ? 'None'
                  : lead['contact_name']?.toString() ?? 'None';
              final email = lead['email_from'] ?? 'None';
              final stageName = lead['stage_id'] != null &&
                      lead['stage_id'] is List &&
                      lead['stage_id'].length > 1
                  ? lead['stage_id'][1]
                  : "None";
              final salesperson = lead['user_id'] != null &&
                      lead['user_id'] is List &&
                      lead['user_id'].length > 1
                  ? lead['user_id'][1]
                  : "None";
              final mrr = lead['recurring_revenue_monthly'] ?? 'None';
              final hasActivity = lead['activity_ids'] != null &&
                  lead['activity_ids'] is List &&
                  lead['activity_ids'].isNotEmpty;
              final activityIds =
                  lead['activity_ids'] != null && lead['activity_ids'] is List
                      ? List<int>.from(lead['activity_ids'])
                      : [];
              final activityState =
                  lead['activity_state']?.toString().toLowerCase() ?? 'None';
              imageData:
              profileImage != null ? base64Encode(profileImage!) : null;

              Color stageColor;
              if (stageName.toLowerCase().contains('new')) {
                stageColor = Colors.red.shade200;
              } else if (stageName.toLowerCase().contains('qualified')) {
                stageColor = Colors.orange.shade200;
              } else if (stageName.toLowerCase().contains('proposition')) {
                stageColor = Colors.blue.shade200;
              } else if (stageName.toLowerCase().contains('won')) {
                stageColor = Colors.green.shade200;
              } else {
                stageColor = Colors.purple.shade200;
              }

              return isLoading
                  ? Center(
                      child: LoadingAnimationWidget.fourRotatingDots(
                      color: Color(0xFF9EA700),
                      size: 100,
                    ))
                  : Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      // Rounded corners
                      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          color: Color(0x69EA700),
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
                                      color: stageColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: stageColor.withOpacity(0.3),
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
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: stageColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: stageColor, width: 1.5),
                                    ),
                                    child: Text(
                                      stageName,
                                      style: TextStyle(
                                        color: stageColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(
                                  height: 24,
                                  thickness: 1,
                                  color: Colors.grey.shade200),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                          email.isNotEmpty
                                              ? Row(
                                                  children: [
                                                    Icon(Icons.email_outlined,
                                                        size: 14,
                                                        color: Colors.blue),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        email,
                                                        style: TextStyle(
                                                          color: Colors.blue,
                                                          fontSize: 13,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : SizedBox(),
                                          SizedBox(height: 16),
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              profileImage != null
                                                  ? Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.1),
                                                            blurRadius: 4,
                                                            offset:
                                                                Offset(0, 2),
                                                          ),
                                                        ],
                                                        image: DecorationImage(
                                                          image: MemoryImage(
                                                              profileImage!),
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            Colors
                                                                .blue.shade700,
                                                            Colors.blue.shade500
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.blue
                                                                .withOpacity(
                                                                    0.3),
                                                            blurRadius: 4,
                                                            offset:
                                                                Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(Icons.person,
                                                          size: 18,
                                                          color: Colors.white),
                                                    ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  userName ?? 'Loading...',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Expected Revenue',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF9EA700)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '\$${revenue}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF9EA700),
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Expected MRR',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF9EA700)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '\$${mrr}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF9EA700),
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: Icon(
                                      Icons.email_outlined,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    label: Text('Email'),
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Color(0xFF9EA700).withOpacity(0.15),
                                      foregroundColor: Color(0xFF9EA700),
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        //   // side: BorderSide(color: Colors.green.shade200),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    icon: Icon(
                                      Icons.message_outlined,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    label: Text('Message'),
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Color(0xFF9EA700).withOpacity(0.15),
                                      foregroundColor: Color(0xFF9EA700),
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        // side: BorderSide(color: Colors.green.shade200),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  if (hasActivity &&
                                      activityState.toLowerCase() != "overdue")
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: Icon(
                                          Icons.snooze_rounded,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                        label: Text(
                                          'Snooze 7d',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.grey.withOpacity(0.15),
                                          foregroundColor: Colors.grey,
                                          elevation: 0,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
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

  Widget iconSelectedView() {
    final config = AppFlowyBoardConfig(
      groupBackgroundColor: Colors.grey.shade100,
      stretchGroupHeight: false,
    );
    switch (selectedView) {
      case 0:
        return AppFlowyBoard(
            controller: controller,
            cardBuilder: (context, group, groupItem) {
              return AppFlowyGroupCard(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                key: ValueKey(groupItem.id),
                child: customCard(groupItem),
              );
            },
            boardScrollController: boardController,
            footerBuilder: (context, columnData) {
              return AppFlowyGroupFooter(
                // icon: const Icon(Icons.add, size: 20),
                // title: const Text('New'),
                height: 50,
                margin: config.groupBodyPadding,
                onAddButtonClick: () {
                  boardController.scrollToBottom(columnData.id);
                },
              );
            },
            headerBuilder: (context, columnData) {
              return AppFlowyGroupHeader(
                icon: const Icon(Icons.lightbulb_circle),
                title: SizedBox(
                  width: 60,
                  child: TextField(
                    controller: TextEditingController()
                      ..text = columnData.headerData.groupName,
                    onSubmitted: (val) {
                      controller
                          .getGroupController(columnData.headerData.groupId)!
                          .updateGroupName(val);
                    },
                  ),
                ),
                addIcon: const Icon(Icons.add, size: 20),
                moreIcon: const Icon(Icons.more_horiz, size: 20),
                height: 50,
                margin: config.groupBodyPadding,
              );
            },
            groupConstraints: const BoxConstraints.tightFor(width: 240),
            config: config);
      case 1:
        return listCard();

      case 2:
        return calendarView();

      case 3:
        return fetchData();

      case 4:
        return Container();

      case 5:
        return Container();

      default:
        return Container();
    }
  }

  Widget calendarView() {
    List<Appointment> appointments = [];
    Map<String, Map<String, dynamic>> appointmentLeadMap = {};

    for (var lead in leadsList) {
      if (lead['activity_date_deadline'] != null && lead['activity_date_deadline'] != false) {
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
              id: appointmentId
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
        headerStyle: CalendarHeaderStyle(backgroundColor:  Color(0x69EA700),),
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

  void calendarDialogue(BuildContext context, Map<String, dynamic> lead){
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Opportunity Details',
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
                  '\$${lead['expected_revenue']?.toString() ?? '0.00'}',
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
                  lead['activity_date_deadline'] != null && lead['activity_date_deadline'] != false
                      ? lead['activity_date_deadline'] is DateTime
                      ? lead['activity_date_deadline'].toString().split(' ')[0]
                      : lead['activity_date_deadline'].toString()
                      : 'No deadline',
                  style: TextStyle(
                    fontSize: 16,
                    color: lead['activity_state'] == 'overdue' ? Colors.red : null,
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
                  icon: Icon(Icons.edit, size: 16, color: Colors.black,),
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
                  icon: Icon(Icons.delete, size: 16,color: Colors.black,),
                  label: Text('Delete'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:  Colors.grey[200],
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


  Widget ActivityIconDesign(String activityState, String activityType) {
    IconData iconData;
    Color iconColor;
    if (activityType.isEmpty) {
      iconData = Icons.access_time;
    } else if (activityType.toLowerCase().contains('call') ||
        activityType.toLowerCase().contains('phone')) {
      iconData = Icons.phone_outlined;
    } else if (activityType.toLowerCase().contains('email') ||
        activityType.toLowerCase().contains('mail')) {
      iconData = Icons.email_outlined;
    } else if (activityType.toLowerCase().contains('meeting')) {
      iconData = Icons.event;
    } else if (activityType.toLowerCase().contains('todo')) {
      iconData = Icons.check_circle;
    } else {
      iconData = Icons.calendar_today;
    }

    if (activityState == 'overdue') {
      iconColor = Colors.red;
    } else if (activityState == 'today') {
      iconColor = Colors.orange;
    } else if (activityState == 'planned') {
      iconColor = Colors.green;
    } else {
      iconColor = Colors.grey;
    }

    if (activityState.isEmpty) {
      return SizedBox();
    }

    return Container(
      child: Icon(
        iconData,
        size: 16,
        color: iconColor,
      ),
    );
  }

  Widget fetchData() {
    if (leadsList.isEmpty) {
      print("No data ");
      return Center(child: Text("No data available"));
    }

    Set<String> uniqueStages = {};
    Map<String, Map<String, dynamic>> groupedData = {};

    for (var lead in leadsList) {
      String stage = (lead['stage_id'] is List && lead['stage_id'].length > 1)
          ? lead['stage_id'][1]
          : 'Unknown';
      if (!uniqueStages.contains(stage)) {
        uniqueStages.add(stage);
      }
      // uniqueStages.add(stage);
      String date = lead['create_date'] ?? "None";
      String formattedDate = formatDate(date);
      print('klkll$date');
      double revenue = double.tryParse(lead['expected_revenue']?.toString() ?? "0") ?? 0.0;

      // Initialize the date row if not present
      // groupedData.putIfAbsent(formattedDate, () => {'date': formattedDate});
      if (!groupedData.containsKey(formattedDate)) {
        groupedData[formattedDate] = {'date': formattedDate};
      }

      groupedData[formattedDate]![stage] =
          ((double.tryParse(groupedData[formattedDate]![stage]?.toString() ?? "0") ?? 0.0) + revenue).toString();
    }

    List<GridColumn> columns = [
      GridColumn(
        columnName: 'date',
        label: Container(
          alignment: Alignment.center,
          child: Text(
            '',
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
              stage,
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

    return SfDataGrid(
      source: tableSource(rows),
      columns: columns,
      columnWidthMode: ColumnWidthMode.fill,
    );
  }


  Widget customCard(AppFlowyGroupItem item) {
    if (item is LeadItem) {
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF9EA700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\$${item.revenue}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9EA700),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    item.customerName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(
                    height: 6,
                  ),
                  Wrap(
                    spacing: 5,
                    children: item.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tag, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...List.generate(
                        3,
                        (index) => Icon(
                          index < item.priority
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ActivityIconDesign(item.activityState, item.activityType),
                      SizedBox(
                        width: 58,
                      ),
                      if (item.imageData != null && item.imageData!.isNotEmpty)
                        Container(
                          width: 24,
                          height: 24,
                          margin: EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            image: DecorationImage(
                              image: MemoryImage(
                                base64Decode(item.imageData!),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 24,
                          height: 24,
                          margin: EdgeInsets.only(left: 55),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade300,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    throw UnimplementedError();
  }

  @override
  void initState() {
    super.initState();
    initializeOdooClient();
    boardController = AppFlowyBoardScrollController();
  }

  @override
  Widget build(BuildContext context) {
    // final config = AppFlowyBoardConfig(
    //   groupBackgroundColor: Colors.grey.shade100,
    //   stretchGroupHeight: false,
    // );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF9EA700),
        title: Text('Pipeline'),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.search_rounded)),
          SizedBox(
            width: 4,
          ),
          IconButton(onPressed: () {}, icon: Icon(Icons.filter_list_sharp)),
          SizedBox(
            width: 4,
          ),
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
                  'Pipeline',
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
                      'Generate Leads',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    )),
              ],
            ),
          ),
          Divider(thickness: 1, color: Colors.grey.shade300),
          ChartSelection(),
          Divider(thickness: 1, color: Colors.grey.shade300),
          SizedBox(
            height: 25,
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
    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(8.0),
          child: Text(cell.value.toString()),
        );
      }).toList(),
    );
  }
}

String formatDate(String date) {
  try {
    DateTime parsedDate = DateTime.parse(date);
    return DateFormat("MMMM yyyy").format(parsedDate);
  } catch (e) {
    return "Unknown";
  }
}


class LeadItem extends AppFlowyGroupItem {
  final String name;
  final String revenue;
  final String customerName;
  final List<String> tags;
  final int priority;
  final String activityState;
  final String activityType;
  final String? imageData;
  final bool hasActivity;
  final List<String> activityIds;

  LeadItem({
    required this.name,
    required this.revenue,
    required this.customerName,
    required this.tags,
    required this.priority,
    this.activityState = '',
    this.activityType = '',
    this.imageData,
    required this.hasActivity,
    required this.activityIds,
  });

  @override
  String get id => name;
}
