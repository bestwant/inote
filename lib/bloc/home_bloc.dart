import 'package:flutter/material.dart';
import 'package:inote/bloc/bloc_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inote/bloc/node_list_bloc.dart';
import 'package:inote/edtor/full_page.dart';
import 'package:inote/edtor/period_setting.dart';
import 'package:inote/utils/toast_utils.dart';
import 'package:inote/persistence/note_provider.dart';
import 'package:inote/persistence/remind_provider.dart';

class HomeBloc extends BlocBase {
  final BuildContext _buildContext;

  RemindProvider _remindProvider;
  NoteProvider _noteProvider;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  NoteListBloc _noteListBloc;

  HomeBloc(this._buildContext);

  @override
  void dispose() {
    // TODO: implement dispose
  }

  @override
  void initState() {
    // TODO: implement initState
    _initNotification();
    _noteProvider = NoteProvider();
    _remindProvider = RemindProvider();
  }

  Future _initNotification() async {
    flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        new AndroidInitializationSettings('ic_launcher');
    var initializationSettingsIOS = new IOSInitializationSettings();
    var initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);
  }

  //设置某条笔记完成
  Future setNoteFinished({Note note}) async {
    List<Remind> reminds =
        await _remindProvider.listRemind(noteId: note.id, isDone: false);
    if (reminds != null && reminds.length > 0) {
      for (var remind in reminds) {
        await flutterLocalNotificationsPlugin.cancel(remind.notifyId); //取消提醒
      }
    }
    await _remindProvider.deleteAllRemind(noteId: note.id);
  }

  ///艾宾浩斯遗忘周期提醒
  Future showNotifyPeriodically(
      {Note note, List<PeriodSettingStr> periodList}) async {
    int initRemindId = await _remindProvider.getMaxNotifyId();
    List<Remind> list = List();
    initRemindId++;

    for (var periodSettingStr in periodList) {
      list.add(Remind(
          noteId: note.id,
          notifyId: initRemindId,
          time: periodSettingStr.schedule,
          done: false));
      initRemindId++;
    }

    var i = 0;
    for (var remind in list) {
      i++;
      remind = await _remindProvider.insert(remind);
      print('插入提醒成功,$remind');
      var scheduledNotificationDateTime =
          new DateTime.now().add(new Duration(seconds: remind.time));
      var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
          '404', 'inote remind', 'it is time for you to remind your note now');
      var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
      NotificationDetails platformChannelSpecifics = new NotificationDetails(
          androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.schedule(
          remind.notifyId,
          note.title,
          "第$i次提醒",
          scheduledNotificationDateTime,
          platformChannelSpecifics,
          payload: '${remind.notifyId}');
    }
  }

  Future onSelectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
      //fix seem that it is useless..
      await _remindProvider.setNotifyDone(notifyId: int.parse(payload));
      Remind remind =
          await _remindProvider.getRemind(notifyId: int.parse(payload));
      Note note = await _noteProvider.getNote(remind.noteId);
      if(note==null){
        showToast("该笔记已删除");
        return;
      }
      int maxNotifyId =
          await _remindProvider.getMaxNotifyIdByNoteId(noteId: remind.noteId);
      if (maxNotifyId == int.parse(payload)) {
        //最晚的一条提醒已经查看
        _remindProvider.deleteAllRemind(noteId: remind.noteId);
        note.done = true;
        await _noteProvider.update(note);
        if (_noteListBloc != null) {
          _noteListBloc.onDone(note);
        }
      }
      print("进入详情$note");
      await Navigator.push(
        _buildContext,
        new MaterialPageRoute(
            builder: (context) => new FullPageEditorScreen(
                  note: note,
                  noteListBloc: _noteListBloc,
                )),
      );
    } else {
      debugPrint("notification can't find");
    }
  }

  void setNoteListBloc(NoteListBloc noteListBloc) {
    _noteListBloc = noteListBloc;
  }
}
