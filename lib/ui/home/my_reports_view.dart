import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:podd_app/components/progress_indicator.dart';
import 'package:podd_app/locator.dart';
import 'package:podd_app/models/entities/incident_report.dart';
import 'package:podd_app/ui/home/my_reports_view_model.dart';
import 'package:podd_app/ui/report/followup_report_form_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_hooks/stacked_hooks.dart';

import 'report_list_view.dart';

class MyReportsView extends StatelessWidget {
  final viewModel = locator<MyReportsViewModel>();

  MyReportsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<MyReportsViewModel>.reactive(
        viewModelBuilder: () => viewModel,
        disposeViewModel: false,
        initialiseSpecialViewModelsOnce: true,
        builder: (context, viewModel, child) => _ReportList());
  }
}

class _ReportList extends HookViewModelWidget<MyReportsViewModel> {
  final _logger = locator<Logger>();
  final formatter = DateFormat("dd/MM/yyyy HH:mm");

  @override
  Widget buildViewModelWidget(
      BuildContext context, MyReportsViewModel viewModel) {
    final isMounted = useIsMounted();
    useEffect(() {
      if (isMounted()) {
        viewModel.refetchIncidentReports();
      }
      return null;
    }, []);
    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refetchIncidentReports();
      },
      child: !viewModel.isBusy
          ? ReportListView(
              viewModel: viewModel,
              key: const PageStorageKey('my-reports-storage-key'),
              trailingFn: (report) {
                var children = <Widget>[];
                if (viewModel.canFollow(report.reportTypeId) &&
                    !report.testFlag) {
                  children.insert(0, _followLink(context, report, viewModel));
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: children,
                );
              },
            )
          : const Center(
              child: OhtkProgressIndicator(
              size: 100,
            )),
    );
  }

  Widget _followLink(BuildContext context, IncidentReport report,
      MyReportsViewModel viewModel) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FollowupReportFormView(
              incidentId: report.id,
              reportType: viewModel.getReportType(report.reportTypeId)!,
            ),
          ),
        ).then((value) => {_logger.d("back from from $value")});
      },
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Text(
            "Follow",
            style: TextStyle(
              color: Colors.white,
            ),
            textScaleFactor: 0.8,
          ),
        ),
      ),
    );
  }
}
