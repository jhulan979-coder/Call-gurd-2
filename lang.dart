import 'package:flutter/material.dart' as m;
import 'package:shared_preferences/shared_preferences.dart';

final langNotifier = m.ValueNotifier<String>('hi');

Future<void> loadLang() async {
  final p = await SharedPreferences.getInstance();
  langNotifier.value = p.getString('lang') ?? 'hi';
}

Future<void> setLang(String code) async {
  langNotifier.value = code;
  final p = await SharedPreferences.getInstance();
  await p.setString('lang', code);
}

const Map<String, List<String>> _t = {
  'Saara data delete karo?': ['Delete all data?', 'ସମସ୍ତ ଡାଟା ଡିଲିଟ୍ କରିବେ?'],
  'Block list, history aur API key sab hat jayenge.': [
    'The block list, history and API key will all be removed.',
    'ବ୍ଲକ୍ ତାଲିକା, ଇତିହାସ ଓ API key ସବୁ ହଟିଯିବ।'
  ],
  'Saara data delete karo': ['Delete all data', 'ସମସ୍ତ ଡାଟା ଡିଲିଟ୍ କରନ୍ତୁ'],
  'Yes': ['Yes', 'ହଁ'],
  'No': ['No', 'ନା'],
  'Cancel': ['Cancel', 'ବାତିଲ୍'],
  'Number daalo': ['Enter number', 'ନମ୍ବର ଦିଅନ୍ତୁ'],
  'Call karo': ['Call', 'କଲ୍ କରନ୍ତୁ'],
  'Aaj blocked': ['Blocked today', 'ଆଜି ବ୍ଲକ୍ ହୋଇଛି'],
  'Spam alerts': ['Spam alerts', 'ସ୍ପାମ୍ ସତର୍କତା'],
  'Recent calls': ['Recent calls', 'ସାମ୍ପ୍ରତିକ କଲ୍'],
  'Recent calls dekhne ke liye call log ki permission do.': [
    'Allow call log permission to see recent calls.',
    'ସାମ୍ପ୍ରତିକ କଲ୍ ଦେଖିବାକୁ କଲ୍ ଲଗ୍ ଅନୁମତି ଦିଅନ୍ତୁ।'
  ],
  'Permission do': ['Allow permission', 'ଅନୁମତି ଦିଅନ୍ତୁ'],
  'Koi call nahi mili': ['No calls found', 'କୌଣସି କଲ୍ ମିଳିଲା ନାହିଁ'],
  'abhi': ['just now', 'ଏବେ'],
  'Call history se delete karein?': [
    'Delete from call history?',
    'କଲ୍ ଇତିହାସରୁ ଡିଲିଟ୍ କରିବେ?'
  ],
  'Permission allow karke dobara try karo': [
    'Allow the permission and try again',
    'ଅନୁମତି ଦେଇ ପୁଣି ଚେଷ୍ଟା କରନ୍ତୁ'
  ],
  'Contacts': ['Contacts', 'ଯୋଗାଯୋଗ'],
  'Recent calls dekhne ke liye call log ki permission chahiye. Ye data sirf aapke phone me rehta hai.': [
    'Call log permission is needed to see recent calls. This data stays only on your phone.',
    'ସାମ୍ପ୍ରତିକ କଲ୍ ଦେଖିବାକୁ କଲ୍ ଲଗ୍ ଅନୁମତି ଦରକାର। ଏହି ଡାଟା କେବଳ ଆପଣଙ୍କ ଫୋନ୍‌ରେ ରହେ।'
  ],
  'Permission nahi mili. Phone Settings > Apps > Call Guard > Permissions > Call logs me Allow karo, phir yahan wapas aao.': [
    'Permission not granted. Open Phone Settings > Apps > Call Guard > Permissions > Call logs, tap Allow, then come back.',
    'ଅନୁମତି ମିଳିଲା ନାହିଁ। ଫୋନ୍ Settings > Apps > Call Guard > Permissions > Call logs ରେ Allow କରନ୍ତୁ, ତାପରେ ଫେରି ଆସନ୍ତୁ।'
  ],
  'Contacts dekhne ke liye Contacts ki permission chahiye. Ye data sirf aapke phone me rehta hai.': [
    'Contacts permission is needed to see contacts. This data stays only on your phone.',
    'ଯୋଗାଯୋଗ ଦେଖିବାକୁ Contacts ଅନୁମତି ଦରକାର। ଏହି ଡାଟା କେବଳ ଆପଣଙ୍କ ଫୋନ୍‌ରେ ରହେ।'
  ],
  'Permission nahi mili. Phone Settings > Apps > Call Guard > Permissions > Contacts me Allow karo, phir yahan wapas aao.': [
    'Permission not granted. Open Phone Settings > Apps > Call Guard > Permissions > Contacts, tap Allow, then come back.',
    'ଅନୁମତି ମିଳିଲା ନାହିଁ। ଫୋନ୍ Settings > Apps > Call Guard > Permissions > Contacts ରେ Allow କରନ୍ତୁ, ତାପରେ ଫେରି ଆସନ୍ତୁ।'
  ],
  'Koi recent call nahi mili': [
    'No recent calls found',
    'କୌଣସି ସାମ୍ପ୍ରତିକ କଲ୍ ମିଳିଲା ନାହିଁ'
  ],
  'Koi contact nahi mila': ['No contacts found', 'କୌଣସି ଯୋଗାଯୋଗ ମିଳିଲା ନାହିଁ'],
  'Blocked': ['Blocked', 'ବ୍ଲକ୍ ହୋଇଛି'],
  'Unknown': ['Unknown', 'ଅଜ୍ଞାତ'],
  'Shak: telemarketing / promotional number': [
    'Suspicious: telemarketing / promotional number',
    'ସନ୍ଦେହ: ଟେଲିମାର୍କେଟିଂ / ପ୍ରଚାର ନମ୍ବର'
  ],
  'Koi spam report nahi mili': [
    'No spam report found',
    'କୌଣସି ସ୍ପାମ୍ ରିପୋର୍ଟ ମିଳିଲା ନାହିଁ'
  ],
  'Category chuno:': ['Choose a category:', 'ବର୍ଗ ବାଛନ୍ତୁ:'],
  'Block list me daalo': ['Add to block list', 'ବ୍ଲକ୍ ତାଲିକାରେ ରଖନ୍ତୁ'],
  'Block hatao': ['Remove block', 'ବ୍ଲକ୍ ହଟାନ୍ତୁ'],
  'AI se poochho': ['Ask AI', 'AI କୁ ପଚାରନ୍ତୁ'],
  'Poora 10 digit number daalo': [
    'Enter the full 10-digit number',
    'ପୂର୍ଣ୍ଣ 10 ଅଙ୍କର ନମ୍ବର ଦିଅନ୍ତୁ'
  ],
  'International number, savdhan rahein': [
    'International number, be careful',
    'ଆନ୍ତର୍ଜାତିକ ନମ୍ବର, ସାବଧାନ ରୁହନ୍ତୁ'
  ],
  'Shak: sabhi digit ek jaise hain': [
    'Suspicious: all digits are the same',
    'ସନ୍ଦେହ: ସମସ୍ତ ଅଙ୍କ ଏକା'
  ],
  'Number check karo': ['Check number', 'ନମ୍ବର ଯାଞ୍ଚ କରନ୍ତୁ'],
  'Number block karo': ['Block a number', 'ନମ୍ବର ବ୍ଲକ୍ କରନ୍ତୁ'],
  'Block': ['Block', 'ବ୍ଲକ୍'],
  'Hatane ke liye side me swipe karo': [
    'Swipe sideways to remove',
    'ହଟାଇବାକୁ ପାଖକୁ ସ୍ୱାଇପ୍ କରନ୍ତୁ'
  ],
  'Koi number nahi mila': ['No numbers found', 'କୌଣସି ନମ୍ବର ମିଳିଲା ନାହିଁ'],
  'Settings': ['Settings', 'ସେଟିଂସ୍'],
  'Call Guard default Phone app hai': [
    'Call Guard is the default Phone app',
    'Call Guard ଡିଫଲ୍ଟ ଫୋନ୍ ଆପ୍ ଅଟେ'
  ],
  'Call Guard default Phone app nahi hai': [
    'Call Guard is not the default Phone app',
    'Call Guard ଡିଫଲ୍ଟ ଫୋନ୍ ଆପ୍ ନୁହେଁ'
  ],
  'Naam bolna, flip to silence aur Call Guard ki call screen tabhi chalti hain jab ye default ho.': [
    'Announcing the caller name, flip to silence and the Call Guard call screen work only when it is the default.',
    'କଲର୍ ନାମ କହିବା, flip to silence ଓ Call Guard କଲ୍ ସ୍କ୍ରିନ୍ କେବଳ ଡିଫଲ୍ଟ ହେଲେ କାମ କରେ।'
  ],
  'Default Phone app banao': ['Make default Phone app', 'ଡିଫଲ୍ଟ ଫୋନ୍ ଆପ୍ କରନ୍ତୁ'],
  'Call blocking': ['Call blocking', 'କଲ୍ ବ୍ଲକିଂ'],
  'Auto call blocking': ['Auto call blocking', 'ସ୍ୱୟଂଚାଳିତ କଲ୍ ବ୍ଲକିଂ'],
  'Block list wale numbers ki call apne aap reject': [
    'Calls from numbers on the block list are rejected automatically',
    'ବ୍ଲକ୍ ତାଲିକାର ନମ୍ବରରୁ କଲ୍ ନିଜେ ନିଜେ ପ୍ରତ୍ୟାଖ୍ୟାନ ହେବ'
  ],
  'Telemarketing numbers block karo': [
    'Block telemarketing numbers',
    'ଟେଲିମାର୍କେଟିଂ ନମ୍ବର ବ୍ଲକ୍ କରନ୍ତୁ'
  ],
  '140 aur 160 se shuru hone wale numbers. Kuch bank bhi 160 se call karte hain': [
    'Numbers starting with 140 and 160. Some banks also call from 160',
    '140 ଓ 160 ରୁ ଆରମ୍ଭ ହେଉଥିବା ନମ୍ବର। କିଛି ବ୍ୟାଙ୍କ ମଧ୍ୟ 160 ରୁ କଲ୍ କରନ୍ତି'
  ],
  'Chhupe hue number block karo': [
    'Block hidden numbers',
    'ଲୁଚିଥିବା ନମ୍ବର ବ୍ଲକ୍ କରନ୍ତୁ'
  ],
  'Jinka number dikhta nahi (hidden / private)': [
    'Callers whose number is not shown (hidden / private)',
    'ଯେଉଁମାନଙ୍କ ନମ୍ବର ଦେଖାଯାଏ ନାହିଁ (hidden / private)'
  ],
  'Videsh ke numbers block karo': [
    'Block international numbers',
    'ବିଦେଶୀ ନମ୍ବର ବ୍ଲକ୍ କରନ୍ତୁ'
  ],
  '+91 ke alawa kisi bhi desh ka number': [
    'Any number from a country other than +91',
    '+91 ବ୍ୟତୀତ ଅନ୍ୟ ଯେକୌଣସି ଦେଶର ନମ୍ବର'
  ],
  'Block hui call ka notification': [
    'Blocked call notification',
    'ବ୍ଲକ୍ ହୋଇଥିବା କଲ୍ ବିଜ୍ଞପ୍ତି'
  ],
  'Call reject hone par notification': [
    'Notification when a call is rejected',
    'କଲ୍ ପ୍ରତ୍ୟାଖ୍ୟାନ ହେଲେ ବିଜ୍ଞପ୍ତି'
  ],
  'Awaaz aur ring': ['Voice and ring', 'ସ୍ୱର ଓ ରିଙ୍ଗ'],
  'Naam bolna': ['Announce caller name', 'କଲର୍ ନାମ କହିବା'],
  'Call aane par naam ya Unknown number bolna': [
    'Say the name or "Unknown number" when a call comes in',
    'କଲ୍ ଆସିଲେ ନାମ କିମ୍ବା Unknown number କହିବା'
  ],
  'Spam caller awaaz': ['Spam caller voice', 'ସ୍ପାମ୍ କଲର୍ ସ୍ୱର'],
  '140 ya 160 wale numbers par Spam caller bolna': [
    'Say "Spam caller" for numbers starting with 140 or 160',
    '140 କିମ୍ବା 160 ନମ୍ବରରେ Spam caller କହିବା'
  ],
  'Flip to silence': ['Flip to silence', 'Flip to silence'],
  'Ring ke dauran phone ulta karne par ringtone band': [
    'Ringtone stops when you turn the phone face down while it rings',
    'ରିଙ୍ଗ ବେଳେ ଫୋନ୍ ଓଲଟାଇଲେ ରିଙ୍ଗଟୋନ୍ ବନ୍ଦ ହେବ'
  ],
  'Unknown number ka state (online AI)': [
    'State of unknown number (online AI)',
    'ଅଜ୍ଞାତ ନମ୍ବରର ରାଜ୍ୟ (online AI)'
  ],
  'Gemini API key se. Number Google ko jata hai': [
    'Uses the Gemini API key. The number is sent to Google',
    'Gemini API key ଦ୍ୱାରା। ନମ୍ବର Google କୁ ଯାଏ'
  ],
  'Notification': ['Notification', 'ବିଜ୍ଞପ୍ତି'],
  'Unknown caller ka chhota popup': [
    'Small unknown-caller popup',
    'ଅଜ୍ଞାତ କଲର୍ ଛୋଟ ପପ୍‌ଅପ୍'
  ],
  'Call aane par Call Guard ka notification': [
    'Call Guard notification when a call comes in',
    'କଲ୍ ଆସିଲେ Call Guard ବିଜ୍ଞପ୍ତି'
  ],
  'Daali nahi gayi': ['Not set', 'ଦିଆଯାଇ ନାହିଁ'],
  'Save': ['Save', 'ସେଭ୍ କରନ୍ତୁ'],
  'About': ['About', 'ବିଷୟରେ'],
  'Privacy': ['Privacy', 'ଗୋପନୀୟତା'],
  'Block list aur history sirf aapke phone me rehti hai. AI se poochho ya state wale switch par number Google Gemini ko jata hai.': [
    'The block list and history stay only on your phone. When you tap Ask AI or use the state switch, the number is sent to Google Gemini.',
    'ବ୍ଲକ୍ ତାଲିକା ଓ ଇତିହାସ କେବଳ ଆପଣଙ୍କ ଫୋନ୍‌ରେ ରହେ। AI କୁ ପଚାରିଲେ କିମ୍ବା state switch ବ୍ୟବହାର କଲେ ନମ୍ବର Google Gemini କୁ ଯାଏ।'
  ],
  'Language / Bhasha': ['Language', 'ଭାଷା'],
};

const Map<String, List<String>> _p = {
  'Aapki block list me hai': [
    'It is in your block list',
    'ଏହା ଆପଣଙ୍କ ବ୍ଲକ୍ ତାଲିକାରେ ଅଛି'
  ],
  ' min pehle': [' min ago', ' ମିନିଟ୍ ପୂର୍ବରୁ'],
  ' ghante pehle': [' hours ago', ' ଘଣ୍ଟା ପୂର୍ବରୁ'],
  ' din pehle': [' days ago', ' ଦିନ ପୂର୍ବରୁ'],
};

final List<String> _pk = _p.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

String tr(String s) {
  final l = langNotifier.value;
  if (l == 'hi') return s;
  final i = l == 'en' ? 0 : 1;
  final ex = _t[s];
  if (ex != null) return ex[i];
  var out = s;
  for (final k in _pk) {
    if (out.contains(k)) out = out.replaceAll(k, _p[k]![i]);
  }
  return out;
}

class Text extends m.StatelessWidget {
  final String data;
  final m.TextStyle? style;
  final m.TextAlign? textAlign;
  final int? maxLines;
  final m.TextOverflow? overflow;
  final bool? softWrap;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  m.Widget build(m.BuildContext context) {
    return m.ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (c, l, _) => m.Text(
        tr(data),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      ),
    );
  }
}
