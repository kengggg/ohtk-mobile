import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:logger/logger.dart';
import 'package:podd_app/form/form_store.dart';
import 'package:podd_app/form/widgets/validation.dart';
import 'package:provider/provider.dart';
import 'package:podd_app/form/ui_definition/form_ui_definition.dart';
import 'package:podd_app/locator.dart';

import 'package:podd_app/form/form_data/form_data.dart';

class FormIntegerField extends StatefulWidget {
  final IntegerFieldUIDefinition fieldDefinition;

  const FormIntegerField(this.fieldDefinition, {Key? key}) : super(key: key);

  @override
  State<FormIntegerField> createState() => _FormIntegerFieldState();
}

class _FormIntegerFieldState extends State<FormIntegerField> {
  final _logger = locator<Logger>();

  final TextEditingController _controller = TextEditingController();
  UnRegisterValidationCallback? unRegisterValidationCallback;
  bool valid = true;
  String errorMessage = '';

  ValidationState validate() {
    var isValid = true;
    var msg = '';

    if (_controller.text.isEmpty) {
      isValid = false;
      msg = '${widget.fieldDefinition.label} is required';
    }
    if (mounted) {
      setState(() {
        valid = isValid;
        errorMessage = msg;
      });
    }
    return ValidationState(isValid, msg);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (unRegisterValidationCallback != null) {
      unRegisterValidationCallback!();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var formStore = Provider.of<FormStore>(context);
    if (widget.fieldDefinition.required == true) {
      unRegisterValidationCallback = formStore.registerValidation(validate);
    }

    var formData = Provider.of<FormData>(context);
    var formValue =
        formData.getFormValue(widget.fieldDefinition.name) as IntegerFormValue;

    return Observer(builder: (BuildContext context) {
      var value = formValue.value?.toString() ?? '';
      if (value != '' && value != _controller.text) {
        _controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length));
      }

      return TextField(
        controller: _controller,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: widget.fieldDefinition.label,
          suffixText: widget.fieldDefinition.suffixLabel != null
              ? widget.fieldDefinition.suffixLabel!
              : null,
          helperText: widget.fieldDefinition.description != null
              ? widget.fieldDefinition.description!
              : null,
          errorText: valid ? null : errorMessage,
        ),
        onChanged: (val) {
          _logger.d(val);
          if (val != "") {
            try {
              formValue.value = int.parse(val);
              if (!valid) {
                setState(() {
                  valid = true;
                });
              }
            } on FormatException catch (_) {
              _logger.e("parsing error ${val.toString()}");
            }
          }
        },
      );
    });
  }
}
