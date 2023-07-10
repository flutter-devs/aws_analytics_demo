import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:aws_amplify/profile_picture.dart';
import 'package:flutter/material.dart';

import 'amplifyconfiguration.dart';
import 'home_page.dart';
import 'models/ModelProvider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Authenticator(
        child: MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MyHomePage(title: 'Flutter Amplify'),
      // builder: Authenticator.builder(),
    ));
  }

  @override
  void initState() {
    super.initState();
    // _configureAmplify();
  }

  void _configureAmplify() async {
    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.addPlugin(AmplifyStorageS3());
      await Amplify.addPlugin(
          AmplifyAPI(modelProvider: ModelProvider.instance));
      await Amplify.configure(amplifyconfig);
    } on Exception catch (e) {
      print('Error configuring Amplify: $e');
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _languageController = TextEditingController();
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _getUserProfile();
  }

  void _getUserProfile() async {
    final currentUser = await Amplify.Auth.getCurrentUser();
    GraphQLRequest<PaginatedResult<UserProfile>> request = GraphQLRequest(
        document:
            '''query MyQuery { userProfilesByUserId(userId: "${currentUser.userId}") {
    items {
      name
      location
      language
      id
      owner
      createdAt
      updatedAt
      userId
    }
  }}''',
        modelType: const PaginatedModelType(UserProfile.classType),
        decodePath: "userProfilesByUserId");
    final response = await Amplify.API.query(request: request).response;

    if (response.data!.items.isNotEmpty) {
      _userProfile = response.data?.items[0];

      setState(() {
        _nameController.text = _userProfile?.name ?? "";
        _locationController.text = _userProfile?.location ?? "";
        _languageController.text = _userProfile?.language ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Image.asset(
          "assets/background.jpg",
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          fit: BoxFit.cover,
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            // Here we take the value from the MyHomePage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: Text(widget.title),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
          body: Center(
              // Center is a layout widget. It takes a single child and positions it
              // in the middle of the parent.
              child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'User Profile',
                              style: Theme.of(context).textTheme.titleLarge,
                            )),
                        const ProfilePicture(),
                        TextField(
                          decoration: const InputDecoration(labelText: "Name"),
                          controller: _nameController,
                        ),
                        TextField(
                          decoration:
                              const InputDecoration(labelText: "Location"),
                          controller: _locationController,
                        ),
                        TextField(
                          decoration: const InputDecoration(
                              labelText: "Favourite Language"),
                          controller: _languageController,
                        )
                      ],
                    ),
                  ))),
          floatingActionButton: FloatingActionButton(
            onPressed: _updateUserDetails,
            tooltip: 'Save Details',
            child: const Icon(Icons.save),
          ),
        )
      ],
    );
  }

  Future<void> _updateUserDetails() async {
    final currentUser = await Amplify.Auth.getCurrentUser();

    final updatedUserProfile = _userProfile?.copyWith(
            name: _nameController.text,
            location: _locationController.text,
            language: _languageController.text) ??
        UserProfile(
            userId: currentUser.userId,
            name: _nameController.text,
            location: _locationController.text,
            language: _languageController.text);

    final request = _userProfile == null
        ? ModelMutations.create(updatedUserProfile)
        : ModelMutations.update(updatedUserProfile);
    final response = await Amplify.API.mutate(request: request).response;

    final createdProfile = response.data;
    if (createdProfile == null) {
      safePrint('errors: ${response.errors}');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("User details updated")));
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const HomePage()));
  }
}
