import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/feedback/app_error_state.dart';
import '../../logic/students/admin_students_cubit.dart';
import '../../logic/students/admin_students_state.dart';
import '../../models/registered_student.dart';
import 'widgets/student_analytics_tab_view.dart';
import 'widgets/student_courses_tab_view.dart';
import 'widgets/student_profile_header.dart';
import 'widgets/student_receipts_tab_view.dart';

class StudentDetailScreen extends StatelessWidget {
  final RegisteredStudent student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminStudentsCubit, AdminStudentsState>(
      listener: (context, state) {
        if (state is AdminStudentsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is AdminStudentsError && state.students.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('ملف المتدرب')),
            body: AppErrorState(
              message: state.message,
              onRetry: context.read<AdminStudentsCubit>().loadStudents,
            ),
          );
        }

        var current = student;
        if (state is AdminStudentsLoaded) {
          final matches = state.students.where((item) => item.id == student.id);
          if (matches.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('ملف المتدرب')),
              body: const Center(child: Text('لم يعد حساب المتدرب متاحاً.')),
            );
          }
          current = matches.first;
        }

        final isAr = Directionality.of(context) == TextDirection.rtl;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AppBar(
              title: Text(current.name.isNotEmpty ? current.name : (isAr ? 'ملف المتدرب' : 'Student Profile')),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
            ),
            body: SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerScrolled) => [
                  SliverToBoxAdapter(
                    child: StudentProfileHeader(student: current),
                  ),
                ],
                body: Column(
                  children: [
                    Material(
                      color: Colors.white,
                      child: ResponsiveCenter(
                        maxWidth: 920,
                        padding: EdgeInsets.zero,
                        child: TabBar(
                          tabs: [
                            Tab(
                              icon: const Icon(PhosphorIconsRegular.chartPolar, size: 19),
                              text: isAr ? 'التحليل والأداء' : 'Analytics & Performance',
                            ),
                            Tab(
                              icon: const Icon(
                                PhosphorIconsRegular.graduationCap,
                                size: 19,
                              ),
                              text: isAr ? 'الكورسات والصلاحيات' : 'Courses & Access',
                            ),
                            Tab(
                              icon: const Icon(PhosphorIconsRegular.receipt, size: 19),
                              text: isAr ? 'الإيصالات والطلبات' : 'Receipts & Requests',
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          StudentAnalyticsTabView(student: current),
                          StudentCoursesTabView(student: current),
                          StudentReceiptsTabView(student: current),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
