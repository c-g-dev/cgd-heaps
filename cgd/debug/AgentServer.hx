package cgd.debug;

import hxd.App;

/**
	Backward-compatible entry for the agent line protocol.

	Prefer `HeapsProtocolServer.attach` — this class only forwards to the unified
	protocol server (agent transport only; no dashboard).
**/
class AgentServer {
	public function new(app: App, port: Int = 8080) {
		HeapsProtocolServer.attach(app, {
			agentPort: port,
			hostDashboard: false
		});
	}
}
