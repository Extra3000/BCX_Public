import 'dart:ui';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:vux_app/change_light_state.dart';

class LampDetailsPage extends StatefulWidget {
  final String title;

  const LampDetailsPage({required this.title, Key? key}) : super(key: key);

  @override
  State<LampDetailsPage> createState() => _LampDetailsPageState();
}

class _LampDetailsPageState extends State<LampDetailsPage> {
  var on = ValueNotifier(false);

  double power = 0.5;

  // range from 0.0 to 1.0 (0 - 100 %)
  double get normalizedPower => power.clamp(0.0, 1.0);

  Color hue = Colors.blue;

  @override
  void initState() {
    super.initState();
    on.addListener(() {
      changeLightState(on.value);
    });
  }

  @override
  void dispose() {
    on.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: hue,
        primary: hue,
      ),
    ).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    return Theme(
      data: _theme,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // color: on ? hue : null,
                  gradient: on.value
                      ? RadialGradient(
                          colors: [
                            hue,
                            Color.alphaBlend(
                              hue.withOpacity(normalizedPower),
                              Theme.of(context).scaffoldBackgroundColor,
                            ),
                            Theme.of(context).scaffoldBackgroundColor
                          ],
                          tileMode: TileMode.decal,
                          stops: [0.0, normalizedPower, 1.0])
                      : null,
                ),
                child: Icon(
                  on.value ? Icons.lightbulb_outline : Icons.lightbulb,
                  size: 256,
                ),
              ),
              SwitchListTile(
                title: Text(widget.title),
                subtitle: on.value
                    ? const Text('Lamp is on')
                    : const Text('Lamp is off'),
                value: on.value,
                onChanged: (value) => setState(() => on.value = value),
              ),
              ListTile(
                title: Text('Power'),
                subtitle: Text('${(power * 100).toInt()} %'),
                trailing: FractionallySizedBox(
                  widthFactor: 0.6,
                  child: Slider(
                    value: power,
                    onChanged: (value) => setState(() {
                      power = value;
                      on.value = value > 0;
                    }),
                  ),
                ),
              ),
              ListTile(
                title: const Text('Color'),
                isThreeLine: true,
                subtitle: Text(
                  '${hue.hex}\n'
                  'aka ${ColorTools.nameThatColor(hue)}',
                ),
                trailing: ColorIndicator(
                    width: 40,
                    height: 40,
                    borderRadius: 0,
                    color: hue,
                    elevation: 1,
                    onSelectFocus: false,
                    onSelect: () async {
                      // Wait for the dialog to return color selection result.
                      final Color newColor = await showColorPickerDialog(
                        // The dialog needs a context, we pass it in.
                        context,
                        // We use the dialogSelectColor, as its starting color.
                        hue,
                        title: Text('Select color',
                            style: Theme.of(context).textTheme.titleLarge),
                        width: 40,
                        height: 40,
                        spacing: 0,
                        runSpacing: 0,
                        borderRadius: 0,
                        wheelDiameter: 165,
                        enableOpacity: true,
                        showColorCode: true,
                        colorCodeHasColor: true,
                        pickersEnabled: <ColorPickerType, bool>{
                          for (final value in ColorPickerType.values)
                            value: value == ColorPickerType.wheel
                        },
                        /*   copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                          copyButton: true,
                          pasteButton: true,
                          longPressMenu: true,
                        ),*/
                        actionButtons: const ColorPickerActionButtons(
                          okButton: true,
                          closeButton: true,
                          dialogActionButtons: false,
                        ),
                        constraints: const BoxConstraints(
                            minHeight: 480, minWidth: 320, maxWidth: 320),
                      );
                      // We update the dialogSelectColor, to the returned result
                      // color. If the dialog was dismissed it actually returns
                      // the color we started with. The extra update for that
                      // below does not really matter, but if you want you can
                      // check if they are equal and skip the update below.
                      setState(() {
                        hue = newColor;
                      });
                    }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
