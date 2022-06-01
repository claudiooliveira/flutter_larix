import 'package:flutter/material.dart';
import 'package:flutter_larix_example/pages/stream.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Teste flutter larix"),
      ),
      body: Center(
        child: TextButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(
                Color.fromARGB(255, 169, 228, 174)),
          ),
          onPressed: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => Stream()));
          },
          child: Text("fazer stream"),
        ),
      ),
    );
  }
}
