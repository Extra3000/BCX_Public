import 'dart:convert';

import 'package:http/http.dart' as http;
import 'dart:collection';

Future<void> changeLightState(bool state) async {
  var headers = {
    'Content-Type': 'application/json',
    'api-key':
        'wuy1iRhIgGCCyhflo7Z6OZVddEM7niyxs5XAulY1xEVPHvMx4OKgU0UqKc93fjZZ'
  };
  var request = http.Request(
      'POST',
      Uri.parse(
          'https://data.mongodb-api.com/app/data-brqxv/endpoint/data/v1/action/updateOne'));
  request.body = jsonEncode({
    "dataSource": "Cluster0",
    "database": "Building",
    "collection": "Building_1",
    "filter": {"Name": "Shutter_1"},
    "update": {
      r"$set": {"Current_State": state ? "ON" : "OFF"}
    }
  });
  request.headers.addAll(headers);

  http.StreamedResponse response = await request.send();

  if (response.statusCode == 200) {
    print(await response.stream.bytesToString());
  } else {
    print(response.reasonPhrase);
  }
}
