import 'package:agent_cli/agent_cli.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coding CLIs installed on this machine, and in any WSL distribution.
///
/// Refreshed on demand: installing a CLI is not something that happens while
/// the settings screen is open, and probing every environment costs a process
/// each.
final cliAgentsProvider = FutureProvider<List<CliAgent>>(
  (ref) => discoverCliAgents(),
);
