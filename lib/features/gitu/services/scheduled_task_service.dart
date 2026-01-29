import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../models/scheduled_task.dart';

final scheduledTaskServiceProvider = Provider<ScheduledTaskService>((ref) {
  return ScheduledTaskService(ref);
});

final scheduledTasksProvider = FutureProvider.autoDispose<List<ScheduledTask>>((ref) async {
  final service = ref.watch(scheduledTaskServiceProvider);
  return service.getTasks();
});

class ScheduledTaskService {
  final Ref _ref;

  ScheduledTaskService(this._ref);

  Future<List<ScheduledTask>> getTasks() async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>('/gitu/tasks');
    final List<dynamic> tasks = response['tasks'];
    return tasks.map((json) => ScheduledTask.fromJson(json)).toList();
  }

  Future<ScheduledTask> createTask(Map<String, dynamic> data) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.post<Map<String, dynamic>>('/gitu/tasks', data);
    return ScheduledTask.fromJson(response['task']);
  }

  Future<ScheduledTask> updateTask(String id, Map<String, dynamic> data) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.put<Map<String, dynamic>>('/gitu/tasks/$id', data);
    return ScheduledTask.fromJson(response['task']);
  }

  Future<void> deleteTask(String id) async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.delete<Map<String, dynamic>>('/gitu/tasks/$id');
  }

  Future<void> triggerTask(String id) async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.post<Map<String, dynamic>>('/gitu/tasks/$id/trigger', {});
  }

  Future<List<TaskExecution>> getExecutions(String id) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>('/gitu/tasks/$id/executions');
    final List<dynamic> executions = response['executions'];
    return executions.map((json) => TaskExecution.fromJson(json)).toList();
  }
}
