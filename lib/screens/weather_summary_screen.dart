import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/weather_service.dart';
import '../services/llm_service.dart';
import '../main.dart';

class WeatherSummaryScreen extends StatefulWidget {
  const WeatherSummaryScreen({Key? key}) : super(key: key);

  @override
  _WeatherSummaryScreenState createState() => _WeatherSummaryScreenState();
}

class _WeatherSummaryScreenState extends State<WeatherSummaryScreen> {
  final WeatherService _wx = WeatherService();
  final LLMService _llm = LLMService();
  StreamSubscription? _sub;

  bool _loading = true;
  bool _generating = false;
  bool _isFirstToken = true;

  Map<String, dynamic>? _data;
  String _summary = '';
  int _tab = 0; // 0 = hourly, 1 = daily

  @override
  void initState() {
    super.initState();
    _sub = _llm.onTokenStream.listen((event) {
      if (!mounted) return;
      final text = event['text'] as String? ?? '';
      final done = event['done'] as bool? ?? false;
      if (text.isNotEmpty) {
        setState(() {
          if (_isFirstToken) { _summary = text; _isFirstToken = false; }
          else { _summary += text; }
        });
      }
      if (done) setState(() { _generating = false; _isFirstToken = true; });
    });
    _fetch();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _data = null; _summary = ''; });
    final d = await _wx.fetchWeather(lat: 13.884, lon: 122.260);
    if (mounted) setState(() { _data = d; _loading = false; });
  }

  Future<void> _summarize() async {
    if (_data == null) return;
    final c = _data!['current'];
    final rawData = 'Lopez, Quezon: ${c['temperature_2m']}°C, '
        '${_wx.getWeatherDescription(c['weather_code'])}, '
        'Humidity ${c['relative_humidity_2m']}%, '
        'Wind ${c['wind_speed_10m']} km/h, '
        'UV ${c['uv_index']}, Precip ${c['precipitation']} mm';

    setState(() { _summary = ''; _generating = true; _isFirstToken = true; });

    final prompt = '<start_of_turn>user\nYou are HazaAI for Lopez, Quezon. '
        'Summarize this weather in 2-3 bullet points for residents. '
        'Flag any dangerous conditions.\n\n$rawData\n\nSUMMARY:<end_of_turn>\n<start_of_turn>model\n';

    final ok = await _llm.generate(prompt);
    if (!ok && mounted) {
      setState(() { _summary = 'Error: AI model not loaded.'; _generating = false; _isFirstToken = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : _data == null
              ? _errorView()
              : _mainView(),
    );
  }

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.cloud_off, color: AppColors.muted, size: 48),
    const SizedBox(height: 12),
    const Text('Could not load weather', style: TextStyle(color: AppColors.muted)),
    const SizedBox(height: 16),
    _btn('Retry', _fetch),
  ]));

  Widget _mainView() {
    final c = _data!['current'];
    final temp = (c['temperature_2m'] as num).round();
    final feels = (c['apparent_temperature'] as num).round();
    final code = c['weather_code'] as int;
    final isDay = (c['is_day'] ?? 1) == 1;
    final desc = _wx.getWeatherDescription(code);
    final emoji = _wx.getWeatherEmoji(code, isDay: isDay);
    final daily = _data!['daily'];
    final maxT = (daily['temperature_2m_max'][0] as num).round();
    final minT = (daily['temperature_2m_min'][0] as num).round();
    final sunrise = (daily['sunrise'][0] as String).split('T').last;
    final sunset = (daily['sunset'][0] as String).split('T').last;
    final wind = (c['wind_speed_10m'] as num).toDouble();
    final windDir = _wx.getWindDirection((c['wind_direction_10m'] as num).toDouble());
    final uv = (c['uv_index'] as num? ?? 0).toDouble();
    final precip = (daily['precipitation_sum'][0] as num? ?? 0).toDouble();

    return CustomScrollView(
      slivers: [
        // ── App Bar ──
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.bg,
          title: const Text('Weather'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _fetch),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildListDelegate([

            // ── Location + Temp ──
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Lopez, Quezon', style: TextStyle(color: AppColors.muted, fontSize: 13, letterSpacing: 0.2)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$temp°', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w300, height: 1)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('C', style: const TextStyle(color: AppColors.muted, fontSize: 24, fontWeight: FontWeight.w300)),
                  ),
                ]),
                Text(desc, style: const TextStyle(color: AppColors.text, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Feels $feels°  ·  H:$maxT°  L:$minT°', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ])),
              Text(emoji, style: const TextStyle(fontSize: 64)),
            ]),

            const SizedBox(height: 28),
            _divider(),
            const SizedBox(height: 20),

            // ── Forecast Tabs ──
            Row(children: [
              _tabBtn('Hourly', 0),
              const SizedBox(width: 16),
              _tabBtn('Daily', 1),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 8,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _tab == 0 ? _hourlyCard(i) : _dailyCard(i),
              ),
            ),

            const SizedBox(height: 28),
            _divider(),
            const SizedBox(height: 20),

            // ── Detail Grid ──
            _sectionLabel('CONDITIONS'),
            const SizedBox(height: 12),
            _detailGrid(uv, wind, windDir, precip, sunrise, sunset),

            const SizedBox(height: 28),
            _divider(),
            const SizedBox(height: 20),

            // ── HazaAI ──
            _sectionLabel('HAZAAI SUMMARY'),
            const SizedBox(height: 12),
            _hazaAIPanel(),
            const SizedBox(height: 32),
          ])),
        ),
      ],
    );
  }

  Widget _tabBtn(String label, int i) => GestureDetector(
    onTap: () => setState(() => _tab = i),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _tab == i ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _tab == i ? AppColors.border : Colors.transparent),
      ),
      child: Text(label, style: TextStyle(color: _tab == i ? Colors.white : AppColors.muted, fontSize: 13, fontWeight: _tab == i ? FontWeight.w600 : FontWeight.normal)),
    ),
  );

  Widget _hourlyCard(int i) {
    final hourly = _data!['hourly'];
    final now = DateTime.now();
    final idx = (now.hour + i).clamp(0, 23);
    final label = i == 0 ? 'Now' : '${((now.hour + i) % 24).toString().padLeft(2, '0')}:00';
    final temp = (hourly['temperature_2m'][idx] as num).round();
    final prob = hourly['precipitation_probability'][idx] as int? ?? 0;
    final code = hourly['weather_code'][idx] as int? ?? 0;
    return _forecastPill(
      top: label,
      mid: _wx.getWeatherEmoji(code),
      bot: '$temp°',
      sub: prob > 0 ? '$prob%' : null,
      highlight: i == 0,
    );
  }

  Widget _dailyCard(int i) {
    final days = ['Today', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final c = _data!['current'];
    final code = c['weather_code'] as int;
    final daily = _data!['daily'];
    final max = (daily['temperature_2m_max'][0] as num).round();
    final min = (daily['temperature_2m_min'][0] as num).round();
    return _forecastPill(
      top: days[i % days.length],
      mid: _wx.getWeatherEmoji(code),
      bot: '$max°',
      sub: '$min°',
      highlight: i == 0,
    );
  }

  Widget _forecastPill({required String top, required String mid, required String bot, String? sub, bool highlight = false}) => Container(
    width: 68,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: highlight ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: highlight ? AppColors.border : AppColors.border.withOpacity(0.5)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Text(top, style: TextStyle(color: highlight ? Colors.white : AppColors.muted, fontSize: 11)),
      Text(mid, style: const TextStyle(fontSize: 22)),
      if (sub != null) Text(sub, style: const TextStyle(color: AppColors.accent, fontSize: 10)),
      Text(bot, style: TextStyle(color: highlight ? Colors.white : AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _detailGrid(double uv, double wind, String windDir, double precip, String sunrise, String sunset) {
    return Column(children: [
      Row(children: [
        Expanded(child: _detailTile('UV INDEX', '${uv.toStringAsFixed(0)}', _wx.getUVLabel(uv))),
        const SizedBox(width: 10),
        Expanded(child: _detailTile('WIND', '${wind.toStringAsFixed(1)}', 'km/h  $windDir')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _detailTile('SUNRISE', sunrise, 'Sunset  $sunset')),
        const SizedBox(width: 10),
        Expanded(child: _detailTile('RAINFALL', '${precip.toStringAsFixed(1)} mm', 'Last 24 hours')),
      ]),
    ]);
  }

  Widget _detailTile(String label, String value, String sub) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ]),
  );

  Widget _hazaAIPanel() => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      // Header row
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          const Icon(Icons.psychology, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          const Text('Powered by Gemma', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_generating)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
          else if (_summary.isEmpty)
            GestureDetector(
              onTap: _summarize,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                child: const Text('Generate', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            )
          else
            GestureDetector(
              onTap: _summarize,
              child: const Text('Regenerate', style: TextStyle(color: AppColors.accent, fontSize: 12)),
            ),
        ]),
      ),
      if (_summary.isNotEmpty) ...[
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: MarkdownBody(
            data: _summary + (_generating ? ' ▍' : ''),
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.6),
              listBullet: const TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      ],
    ]),
  );

  Widget _btn(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    child: Text(label, style: const TextStyle(color: AppColors.accent)),
  );

  Widget _divider() => const Divider(height: 1, color: AppColors.border);

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
  );
}
