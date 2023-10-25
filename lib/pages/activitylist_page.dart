import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'activity_detail.dart';

class ActivityListPage extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;

  ActivityListPage({
    required this.selectedDate,
    required this.selectedTime,
  });

  Future<String> getSportImage(String sportName) async {
    try {
      // Get a reference to the Firestore collection
      CollectionReference sports =
          FirebaseFirestore.instance.collection('sports');

      // Query Firestore to get the document for the provided sportName
      QuerySnapshot snapshot =
          await sports.where('sport_name', isEqualTo: sportName).get();

      // Check if a document was found
      if (snapshot.docs.isNotEmpty) {
        // Get the image URL from the document
        String imageUrl = snapshot.docs.first['sport_image'];
        return imageUrl;
      } else {
        // If sportName is not found, return a default image URL
        return 'default_image_url_here';
      }
    } catch (e) {
      // Handle errors here
      print('Error fetching sport image: $e');
      // Return a default image URL in case of an error
      return 'default_image_url_here';
    }
  }

  String? userEmail = FirebaseAuth.instance.currentUser?.email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, $userEmail'),
        backgroundColor: Color.fromARGB(255, 230, 0, 0),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('activities')
            .where('activityDate',
                isGreaterThanOrEqualTo:
                    DateFormat('dd-MM-yyyy').format(selectedDate))
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          var activities = snapshot.data!.docs;

          if (activities.isEmpty) {
            return Center(
              child: Text('No activities for now...'),
            );
          }

          // Sort the activities by date
          activities.sort((a, b) {
            DateTime dateA = DateFormat('dd-MM-yyyy').parse(a['activityDate']);
            DateTime dateB = DateFormat('dd-MM-yyyy').parse(b['activityDate']);
            return dateA.compareTo(dateB);
          });

          // Group the activities by date
          Map<String, List<DocumentSnapshot>> activitiesByDate = {};

          for (var activity in activities) {
            String date = activity['activityDate'];
            if (!activitiesByDate.containsKey(date)) {
              activitiesByDate[date] = [];
            }
            activitiesByDate[date]!.add(activity);
          }

          return ListView.builder(
            itemCount: activitiesByDate.length,
            itemBuilder: (BuildContext context, int index) {
              String date = activitiesByDate.keys.elementAt(index);
              List<DocumentSnapshot> activitiesForDate =
                  activitiesByDate[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      date,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: activitiesForDate.length,
                    itemBuilder: (BuildContext context, int index) {
                      var activity = activitiesForDate[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ActivityDetailsPage(activity.id),
                            ),
                          );
                        },
                        child: Card(
                          child: Row(
                            children: [
                              Container(
                                width:
                                    60, // Set a fixed width for the time container
                                padding: EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Column(
                                      children: [
                                        FutureBuilder<String>(
                                          future: getSportImage(
                                              activity['sportName']),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return CircularProgressIndicator();
                                            } else if (snapshot.hasError) {
                                              return Text(
                                                  'Error: ${snapshot.error}');
                                            } else {
                                              return Image.network(
                                                snapshot.data!,
                                                width: 40,
                                                height: 40,
                                              );
                                            }
                                          },
                                        ),
                                        SizedBox(
                                          height: 10,
                                        ),
                                        Text(
                                          activity['activityTime'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(activity['activityTitle'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          )),
                                      Text(
                                          'Location: ${activity['activityLocation']}'),
                                      Text('Fee: ${activity['activityFee']}'),
                                      if (activity['activityType'] ==
                                          'Normal Activity')
                                        Text(
                                            'Duration in hour: ${activity['activityDuration']}'),
                                      Text(
                                          'Quota: (0/${activity['activityQuota']})')
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}