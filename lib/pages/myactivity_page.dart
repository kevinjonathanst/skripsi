import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'activity_detail.dart';
import 'activity_type.dart';

class MyActivityPage extends StatefulWidget {
  @override
  _MyActivityPageState createState() => _MyActivityPageState();
}

class _MyActivityPageState extends State<MyActivityPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color.fromARGB(255, 230, 0, 0),
          title: Text('My Activities'),
          bottom: TabBar(
            labelColor: Colors.white,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'My Activity'),
              Tab(text: 'Activity History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MyActivityTab(), // Create a widget for My Activity tab
            ActivityHistoryTab(), // Create a widget for Activity History tab
          ],
        ),
      ),
    );
  }
}

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

class MyActivityTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String? userEmail = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('activities')
            .where('user_email', isEqualTo: userEmail)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(), // Loading indicator
            );
          }

          var activities = snapshot.data!.docs;

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (BuildContext context, int index) {
              var activity = activities[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActivityDetailsPage(activity.id),
                    ),
                  );
                },
                child: Card(
                  child: Row(
                    children: [
                      Container(
                        width: 60, // Set a fixed width for the time container
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                FutureBuilder<String>(
                                  future: getSportImage(activity['sportName']),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return CircularProgressIndicator();
                                    } else if (snapshot.hasError) {
                                      return Text('Error: ${snapshot.error}');
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(activity['activityTitle'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  )),
                              Text('Location: ${activity['activityLocation']}'),
                              Text('Fee: ${activity['activityFee']}'),
                              if (activity['activityType'] == 'Normal Activity')
                                Text(
                                    'Duration in hour: ${activity['activityDuration']}'),
                              Text('Quota: (0/${activity['activityQuota']})')
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color.fromARGB(255, 230, 0, 0),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActivityTypeChoosePage(),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class ActivityHistoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Activity History Content'),
    );
  }
}
