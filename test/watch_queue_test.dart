import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_screen_app/services/watch_queue.dart';
void main() {
  test('Failed event survives restart with the same id', () async {
    final store = <String,String>{};
    var fail = true;
    final sent = <String>[];
    WatchQueue queue() => WatchQueue(read: (key) async => store[key],
      write: (key,value) async { store[key] = value; }, send: (event) async {
        sent.add(event['id'] as String);
        if (fail) throw Exception('offline');
      });
    final first = queue();
    await first.enqueue(uid:'a',courseId:'c',lessonId:'l',seconds:30);
    await expectLater(first.flush('a'),throwsException);
    expect((jsonDecode(store.values.single) as List).length,1);
    fail = false;
    await queue().flush('a');
    expect(sent[0],sent[1]);
    expect(jsonDecode(store.values.single),isEmpty);
  });
  test('Concurrent enqueue does not overwrite events or mix accounts', () async {
    final store = <String,String>{};
    final sent = <Map<String,dynamic>>[];
    final queue = WatchQueue(read:(key) async=>store[key], write:(key,value) async {store[key]=value;},send:(event) async {sent.add(event);});
    await Future.wait([
      queue.enqueue(uid:'a',courseId:'c',lessonId:'l1',seconds:10),
      queue.enqueue(uid:'a',courseId:'c',lessonId:'l2',seconds:20),
      queue.enqueue(uid:'b',courseId:'d',lessonId:'l3',seconds:30),
    ]);
    await queue.flush('a');
    expect(sent.length,2);
    expect(sent.every((event)=>event['uid']=='a'),isTrue);
    await queue.flush('b');
    expect(sent.length,3);
  });
}
