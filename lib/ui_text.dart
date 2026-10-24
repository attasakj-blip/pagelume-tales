import 'story.dart';

/// The few words the app itself shows, in Thai and English.
class T {
  T(this.lang);
  final Lang lang;
  bool get _th => lang == Lang.th;

  String get appName => 'Pagelume Tales';
  String get shelf => _th ? 'ชั้นหนังสือนิทาน' : 'Story shelf';
  String get read => _th ? 'อ่านนิทาน' : 'Read';
  String get listen => _th ? 'ฟังนิทาน' : 'Listen';
  String get pause => _th ? 'หยุดอ่าน' : 'Pause';
  String get autoTurn => _th ? 'เปิดหน้าเอง' : 'Auto turn';
  String get flipSound => _th ? 'เสียงพลิกหน้า' : 'Page sound';
  String get voices => _th ? 'เสียงตัวละคร' : 'Character voices';
  String get back => _th ? 'กลับชั้นหนังสือ' : 'Back to shelf';
  String get fromStart => _th ? 'อ่านตั้งแต่ต้น' : 'Start again';
  String get phoneVoice => _th ? 'เสียงในเครื่อง' : 'Phone voice';
  String get noVoice => _th
      ? 'เครื่องนี้ยังไม่มีเสียงอ่านภาษาไทย ติดตั้งได้ที่ การตั้งค่า > การช่วยเหลือพิเศษ > เอาต์พุตการอ่านออกเสียง (Google Speech Services)'
      : 'This phone has no English voice yet. Install one in Settings > Accessibility > Text-to-speech output.';
  String get voicesNote => _th
      ? 'แอปใช้เสียงอ่านที่มากับโทรศัพท์ (ฟรี ใช้ได้แม้ไม่มีเน็ต) และปรับเสียงสูงต่ำ ช้าเร็ว ให้เข้ากับแต่ละตัวละคร ถ้าเครื่องมีเสียงผู้ชาย ตัวละครชายจะใช้เสียงผู้ชาย'
      : 'The app uses the phone\'s own voices (free, works offline) and changes pitch and speed for each character. Male characters use a male voice when the phone has one.';
  String voiceType(String v) => switch (v) {
    'youngWoman' => _th ? 'หญิงสาว' : 'Young woman',
    'youngMan' => _th ? 'ชายหนุ่ม' : 'Young man',
    'middleWoman' => _th ? 'หญิงวัยกลางคน' : 'Middle-aged woman',
    'middleMan' => _th ? 'ชายวัยกลางคน' : 'Middle-aged man',
    'girl' => _th ? 'เด็กหญิง' : 'Girl',
    'boy' => _th ? 'เด็กชาย' : 'Boy',
    'oldWoman' => _th ? 'หญิงสูงวัย' : 'Elderly woman',
    'oldMan' => _th ? 'ชายสูงวัย' : 'Elderly man',
    _ => v,
  };
  String pages(int n) => _th ? '$n หน้า' : '$n pages';
}
