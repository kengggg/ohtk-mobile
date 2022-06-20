import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:podd_app/models/entities/report.dart';
import 'package:podd_app/models/report_submit_result.dart';
import 'package:podd_app/services/api/graph_ql_base_api.dart';
import 'package:intl/intl.dart';

class ReportApi extends GraphQlBaseApi {
  ReportApi(GraphQLClient client) : super(client);

  Future<ReportSubmitResult> submit(Report report) async {
    const mutation = r'''
      mutation submitIncidentReport(
        $data: GenericScalar!,
        $reportId: UUID!,
        $reportTypeId: UUID!,
        $incidentDate: Date!,
        $gpsLocation: String
      ){
        submitIncidentReport(data: $data, reportId: $reportId, 
          reportTypeId: $reportTypeId, incidentDate: $incidentDate, 
          gpsLocation: $gpsLocation) {
          id
        }
      }
    ''';
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    try {
      var result = await runGqlMutation(
        mutation: mutation,
        parseData: (data) => data,
        variables: {
          "reportId": report.id,
          "reportTypeId": report.reportTypeId,
          "data": report.data,
          "incidentDate": formatter.format(report.incidentDate),
          "gpsLocation": report.gpsLocation,
        },
      );

      return ReportSubmitSuccess(id: result!["id"]);
    } on OperationException catch (e) {
      return ReportSubmitFailure(e);
    }
  }
}

class ReportSubmitInputType {}
