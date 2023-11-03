import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:intl/intl.dart';
import 'package:sportifyapp/pages/myactivity_page.dart';

import 'activity_detail.dart';

class CreateActivityPage extends StatefulWidget {
  final String activityType;

  CreateActivityPage({required this.activityType});

  @override
  _CreateActivityPageState createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  String? selectedSport;
  TextEditingController activityTitleController = TextEditingController();
  TextEditingController activityLocationController = TextEditingController();
  TextEditingController activityTimeController = TextEditingController();
  TextEditingController activityDateController = TextEditingController();
  TextEditingController activityDescriptionController = TextEditingController();
  TextEditingController activityFeeController = TextEditingController();
  TextEditingController activityDurationController = TextEditingController();
  TextEditingController activityQuotaController = TextEditingController();
  TextEditingController registrationStartController = TextEditingController();
  TextEditingController registrationEndController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  String? userEmail = FirebaseAuth.instance.currentUser?.email;
  bool isSubmitting = false;

  @override
  Future<void> showStatusDialog(String status) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Status'),
          content: Text(status),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (pickedTime != null && pickedTime != selectedTime) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  String padding(angka) {
    if (angka < 10) {
      return "0" + angka.toString();
    } else {
      return angka.toString();
    }
  }

  void addActivity() async {
    try {
      CollectionReference activities =
          FirebaseFirestore.instance.collection('activities');

      int nextActivityID = await getNextActivityID();
      int nextParticipantID = await getNextParticipantID();
      int nextTeamBracketID;
      String? teamID = await checkUserHaveTeam(selectedSport!);
      bool userHaveTeam = teamID != null;

      if (widget.activityType == 'Sparring') {
        if (!userHaveTeam) {
          await showStatusDialog(
              'You must be in a team with the same category to create a Sparring activity.');
          return;
        }
      }

      // Add a new document with the custom ID
      int valueDate =
          int.parse(DateFormat('yyyyMMdd').format(selectedDate).toString());
      int valueTime =
          int.parse(padding(selectedTime.hour) + padding(selectedTime.minute));
      await activities.doc(nextActivityID.toString()).set({
        'activityType': widget.activityType,
        'sportName': selectedSport,
        'activityTitle': activityTitleController.text,
        'activityLocation': activityLocationController.text,
        'activityTime':
            '${padding(selectedTime.hour)}:${padding(selectedTime.minute)}',
        'activityTimeValue': valueTime,
        'activityDate': DateFormat('dd-MM-yyyy').format(selectedDate),
        'activityDateValue': valueDate,
        'activityFee': activityFeeController.text,
        'activityDescription': activityDescriptionController.text,
        'user_email': userEmail,
        if (widget.activityType == 'Normal Activity' ||
            widget.activityType == 'Tournament')
          'activityQuota': int.parse(activityQuotaController.text),
        if (widget.activityType == 'Tournament')
          'registrationStart': registrationStartController.text,
        if (widget.activityType == 'Tournament')
          'registrationEnd': registrationEndController.text,
        if (widget.activityType == 'Sparring') 'activityQuota': "2",
        if (widget.activityType == "Normal Activity")
          'activityisPrivate': isPrivate,
        if (widget.activityType == "Tournament" ||
            widget.activityType == "Sparring")
          'activityisPrivate': true,
        if (widget.activityType == "Normal Activity" ||
            widget.activityType == "Sparring")
          'activityDuration': activityDurationController.text,
        'activityStatus': 'Waiting',
      });

      if (widget.activityType == 'Normal Activity')
        addParticipant(nextActivityID.toString(), userEmail!);
      if (widget.activityType == 'Sparring')
        addTournamentBracket(nextActivityID.toString(), userEmail!, teamID!);

      await updateLatestActivityID(nextActivityID);
      await showStatusDialog('Activity created successfully!');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MyActivityPage(),
        ),
      );
    } catch (e) {
      // Handle errors here
      print('Error adding activity: $e');
      await showStatusDialog('Error creating activity');
    }
  }

  Future<void> addParticipant(String activityID, String userEmail) async {
    try {
      // Get a reference to the participants collection
      CollectionReference participants =
          FirebaseFirestore.instance.collection('participants');

      // Get the next participant ID
      int participantID = await getNextParticipantID();

      // Add the participant
      await participants.doc(participantID.toString()).set({
        'activity_id': activityID,
        'user_email': userEmail,
        'status': 'Confirmed', // You can set an initial status if needed
      });

      await updateLatestParticipantID(participantID);
    } catch (e) {
      // Handle errors here
      print('Error adding participant: $e');
    }
  }

  Future<void> addTournamentBracket(
      String activityID, String userEmail, String teamID) async {
    try {
      CollectionReference brackets =
          FirebaseFirestore.instance.collection('TournamentBracket');

      int bracketID = await getNextBracketID();

      await brackets.doc(bracketID.toString()).set({
        'activity_id': activityID,
        'bracket_id': bracketID,
        'team_id': teamID,
        'bracket_slot': 0,
        'status': 'Confirmed',
      });

      await updateLatestBracketID(bracketID);
    } catch (e) {
      print('Error adding tournament bracket: $e');
    }
  }

  Future<int> getNextParticipantID() async {
    CollectionReference idCollection =
        FirebaseFirestore.instance.collection('latest_participant_id');
    DocumentSnapshot snapshot = await idCollection.doc('latest_id').get();
    int latestID = snapshot.exists ? snapshot['id'] : 0;
    print('latest parcticipant id $latestID');
    return latestID + 1;
  }

  Future<int> getNextBracketID() async {
    CollectionReference idCollection =
        FirebaseFirestore.instance.collection('latest_bracket_id');
    DocumentSnapshot snapshot = await idCollection.doc('latest_id').get();
    int latestID = snapshot.exists ? snapshot['id'] : 0;
    print('latest bracket id $latestID');
    return latestID + 1;
  }

  Future<int> getNextActivityID() async {
    CollectionReference idCollection =
        FirebaseFirestore.instance.collection('latest_activities_id');
    DocumentSnapshot snapshot = await idCollection.doc('latest_id').get();
    int latestID = snapshot.exists ? snapshot['id'] : 0;
    print('latest activity id $latestID');
    return latestID + 1;
  }

  Future<void> updateLatestActivityID(int latestID) async {
    CollectionReference idCollection =
        FirebaseFirestore.instance.collection('latest_activities_id');
    await idCollection.doc('latest_id').set({'id': latestID});
  }

  Future<void> updateLatestParticipantID(int latestID) async {
    CollectionReference idCollection =
        FirebaseFirestore.instance.collection('latest_participant_id');
    await idCollection.doc('latest_id').set({'id': latestID});
  }

  Future<void> updateLatestBracketID(int latestID) async {
    CollectionReference idCollection =
        FirebaseFirestore.instance.collection('latest_bracket_id');
    await idCollection.doc('latest_id').set({'id': latestID});
  }

  Future<String?> checkUserHaveTeam(String sportName) async {
    var userEmail = FirebaseAuth.instance.currentUser?.email;

    if (userEmail != null) {
      var userTeamSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('team_creator_email', isEqualTo: userEmail)
          .where('team_sport', isEqualTo: sportName)
          .get();

      if (userTeamSnapshot.docs.isNotEmpty) {
        return userTeamSnapshot.docs.first.id;
      }
    }

    return null;
  }

  bool isPrivate = false;

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Activity'),
        backgroundColor: Color.fromARGB(255, 230, 0, 0),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Type: ${widget.activityType}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('sports').snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator(); // Loading indicator
                }

                var sportsList = snapshot.data!.docs;
                List<DropdownMenuItem<String>> items = [];

                for (var sportDoc in sportsList) {
                  String sportName = sportDoc['sport_name'];
                  items.add(DropdownMenuItem(
                    value: sportName,
                    child: Text(sportName),
                  ));
                }

                return DropdownButtonFormField<String>(
                  value: selectedSport,
                  items: items,
                  onChanged: (value) {
                    setState(() {
                      selectedSport = value;
                    });
                  },
                  decoration: InputDecoration(labelText: 'Sport'),
                );
              },
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Activity Title'),
              controller: activityTitleController,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Activity Location'),
              controller: activityLocationController,
            ),
            // GooglePlaceAutoCompleteTextField(
            //   textEditingController: activityLocationController,
            //   googleAPIKey: "AIzaSyB1nNrh6n-Be5ziyOBgw-PXylYpJyqC0zU",
            //   inputDecoration: InputDecoration(),
            //   getPlaceDetailWithLatLng: (Prediction prediction) {
            //     // this method will return latlng with place detail
            //     print("placeDetails" + prediction.lng.toString());
            //   }, // this callback is called when isLatLngRequired is true
            //   itemClick: (Prediction prediction) {
            //     //controller.text=prediction.description;
            //     //controller.selection = TextSelection.fromPosition(TextPosition(offset: prediction.description.length));
            //   },
            //   // if we want to make custom list item builder
            //   itemBuilder: (context, index, Prediction prediction) {
            //     return Container(
            //       padding: EdgeInsets.all(10),
            //       child: Row(
            //         children: [
            //           Icon(Icons.location_on),
            //           SizedBox(
            //             width: 7,
            //           ),
            //           Expanded(child: Text("${prediction.description ?? ""}"))
            //         ],
            //       ),
            //     );
            //   },
            //   // if you want to add seperator between list items
            //   seperatedBuilder: Divider(),
            //   // want to show close icon
            //   isCrossBtnShown: true,
            // ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Time Start'),
              style: TextStyle(fontSize: 20),
              onTap: () => _selectTime(context),
              controller: TextEditingController(
                text:
                    "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
              ),
              readOnly: true,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Date Start'),
              style: TextStyle(fontSize: 20),
              onTap: () => _selectDate(context),
              controller: TextEditingController(
                text:
                    "${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}",
              ),
              readOnly: true,
            ),
            TextFormField(
              decoration:
                  InputDecoration(labelText: 'Activity Fee(per person)'),
              controller: activityFeeController,
            ),
            if (widget.activityType == 'Normal Activity' ||
                widget.activityType == 'Sparring')
              TextFormField(
                decoration:
                    InputDecoration(labelText: 'Activity Duration in hour'),
                controller: activityDurationController,
              ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Activity Description'),
              controller: activityDescriptionController,
            ),
            if (widget.activityType == 'Normal Activity' ||
                widget.activityType == 'Tournament')
              TextFormField(
                decoration: InputDecoration(labelText: 'Activity Quota'),
                controller: activityQuotaController,
              ),
            if (widget.activityType == 'Tournament')
              TextFormField(
                decoration: InputDecoration(
                    labelText: 'Registration Start (Date & Time)'),
                controller: registrationStartController,
              ),
            if (widget.activityType == 'Tournament')
              TextFormField(
                decoration: InputDecoration(
                    labelText: 'Registration End (Date & Time)'),
                controller: registrationEndController,
              ),
            SizedBox(height: 20),
            if (widget.activityType == 'Normal Activity') // Add this condition
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Text(
                    'Privacy:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  RadioListTile(
                    value: false,
                    groupValue: isPrivate,
                    onChanged: (value) {
                      setState(() {
                        isPrivate = false;
                      });
                    },
                    title: Text('Anyone can join'),
                  ),
                  RadioListTile(
                    value: true,
                    groupValue: isPrivate,
                    onChanged: (value) {
                      setState(() {
                        isPrivate = true;
                      });
                    },
                    title: Text('Private'),
                  ),
                ],
              ),
            ElevatedButton(
              onPressed: () {
                addActivity(); // Handle the submission of the form here
                // You can access the entered values using the controllers
              },
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
