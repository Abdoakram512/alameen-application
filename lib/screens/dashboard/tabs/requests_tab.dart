import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/widgets/feedback/app_empty_state.dart';
import '../../../core/widgets/feedback/app_error_state.dart';
import '../../../core/widgets/feedback/app_loading_indicator.dart';
import '../../../logic/requests/admin_requests_cubit.dart';
import '../../../logic/requests/admin_requests_state.dart';
import '../../../models/access_request.dart';
import '../widgets/request_card_item.dart';
import 'requests_widgets/requests_filter_header.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  String _query = '';
  AccessStatus? _filter = AccessStatus.pending;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminRequestsCubit, AdminRequestsState>(
      builder: (context, state) {
        if (state is AdminRequestsLoading) {
          return AppLoadingIndicator(
            message: 'requests.loading'.tr(),
          );
        }

        final requests = state is AdminRequestsLoaded
            ? state.requests
            : <CourseAccessRequest>[];

        if (state is AdminRequestsError && requests.isEmpty) {
          return AppErrorState(
            message: state.message,
            onRetry: context.read<AdminRequestsCubit>().loadRequests,
          );
        }

        final pending = requests
            .where((r) => r.status == AccessStatus.pending)
            .length;
        final approved = requests
            .where((r) => r.status == AccessStatus.approved)
            .length;
        final rejected = requests
            .where((r) => r.status == AccessStatus.rejected)
            .length;
        final all = requests.length;

        final filtered = requests
            .where(
              (r) =>
                  (_filter == null || r.status == _filter) &&
                  '${r.studentName} ${r.studentEmail} ${r.courseTitle} ${r.senderNumberOrRef}'
                      .toLowerCase()
                      .contains(_query),
            )
            .toList()
          ..sort((a, b) {
            if (a.status == AccessStatus.pending &&
                b.status != AccessStatus.pending) {
              return -1;
            }
            if (b.status == AccessStatus.pending &&
                a.status != AccessStatus.pending) {
              return 1;
            }
            return b.requestedAt.compareTo(a.requestedAt);
          });

        return RefreshIndicator(
          onRefresh: () async {
            context.read<AdminRequestsCubit>().loadRequests();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 16, bottom: 88),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RequestsFilterHeader(
                      pendingCount: pending,
                      approvedCount: approved,
                      rejectedCount: rejected,
                      allCount: all,
                      errorMessage: state is AdminRequestsError
                          ? state.message
                          : null,
                      searchController: _search,
                      query: _query,
                      selectedFilter: _filter,
                      onQueryChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      onClearQuery: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      onFilterChanged: (filter) =>
                          setState(() => _filter = filter),
                    ),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty)
                      AppEmptyState(
                        icon: Icons.inbox_outlined,
                        title: requests.isEmpty
                            ? 'requests.no_requests'.tr()
                            : 'requests.no_results_found'.tr(),
                        subtitle: requests.isEmpty
                            ? 'requests.no_requests_desc'.tr()
                            : 'requests.no_results_desc'.tr(),
                      )
                    else
                      ResponsiveCardGrid(
                        minItemWidth: 400,
                        maxColumns: 2,
                        mainAxisSpacing: 4,
                        children: filtered
                            .map((request) => RequestCardItem(request: request))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
