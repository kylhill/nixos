#!/usr/bin/env python3
"""Evaluate non-secret settings and exercise an isolated tmux server, never an agent."""

import json
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import subprocess
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(
        args, check=True, text=True, capture_output=True, timeout=60, **kwargs
    ).stdout


class AgentConfig(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = json.loads(run(
            "nix", "eval", "--json", "--no-update-lock-file",
            "path:.#homeConfigurations.syntax.config", "--apply",
            """c: {
              service = c.systemd.user.services.ssh-agent;
              environment = c.systemd.user.sessionVariables;
              profile = c.programs.bash.profileExtra;
              ssh = c.home.file.".ssh/config".text;
              tmux = c.programs.tmux.extraConfig;
              generatedTmux = c.xdg.configFile."tmux/tmux.conf".text;
            }""", cwd=ROOT,
        ))

    def setUp(self):
        self.directory = ROOT / (".agent-fixture-" + uuid.uuid4().hex[:12])
        self.directory.mkdir(mode=0o700)
        self.addCleanup(shutil.rmtree, self.directory)
        self.env = {
            "PATH": os.environ["PATH"],
            "HOME": str(self.directory),
            "XDG_CONFIG_HOME": str(self.directory),
            "XDG_RUNTIME_DIR": str(self.directory),
            "TERM": "xterm-256color",
            "SSH_CONNECTION": "fixture",
            "SSH_AUTH_SOCK": str(self.directory / "forwarded"),
            "SSH_AGENT_PID": "123456",
        }

    def test_native_service_without_loader(self):
        service = self.config["service"]
        self.assertEqual(service["Install"]["WantedBy"], ["default.target"])
        settings = service["Service"]
        self.assertEqual(set(settings), {"Environment", "ExecStart", "SuccessExitStatus"})
        self.assertEqual(settings["Environment"], [])
        self.assertTrue(settings["ExecStart"][0].endswith(
            "/bin/ssh-agent -D -a %t/ssh-agent.socket"))
        self.assertEqual(self.config["environment"]["SSH_AUTH_SOCK"],
                         "${XDG_RUNTIME_DIR}/ssh-agent.socket")
        self.assertNotIn("ssh-add", json.dumps(self.config))

    def test_generated_ssh_on_demand_scope(self):
        config = self.directory / "ssh-config"
        config.write_text(self.config["ssh"])
        for host, trusted in [
            ("syntax", True), ("gateway", True), ("oci", True),
            ("github.com", False), ("git.tacomafia.net", False),
            ("untrusted.invalid", False), ("htpc", False),
        ]:
            with self.subTest(host=host):
                # -G prints configuration only: no connection or private-key reads.
                settings = dict(line.split(" ", 1) for line in run(
                    "ssh", "-G", "-F", str(config), host, env=self.env,
                ).splitlines())
                self.assertEqual(settings["addkeystoagent"], "true" if trusted else "false")
                self.assertEqual(settings["forwardagent"], "yes" if trusted else "no")

    def test_bash_export_precedes_attachment(self):
        profile = self.config["profile"]
        self.assertLess(profile.rindex("export SSH_AUTH_SOCK="),
                        profile.index("exec tmux"))
        run("bash", "-n", input=profile)
        stub = self.directory / "tmux"
        stub.write_text('#!/bin/sh\nprintf "%s|%s|%s" "$SSH_AUTH_SOCK" "${SSH_AGENT_PID-unset}" "$*"\n')
        stub.chmod(0o700)
        env = self.env | {"PATH": f"{self.directory}:{self.env['PATH']}"}
        expected = f"{self.directory}/ssh-agent.socket|unset"
        self.assertEqual(run("bash", "--noprofile", "--norc", "-ic", profile,
                             env=env), expected + "|new-session -A -s 0")
        for flags, extra in [("-c", {}), ("-ic", {"TMUX": "nested"}),
                             ("-ic", {"TERM": "dumb"})]:
            self.assertEqual(run(
                "bash", "--noprofile", "--norc", flags,
                profile + '\nprintf "%s|%s" "$SSH_AUTH_SOCK" "${SSH_AGENT_PID-unset}"',
                env=env | extra,
            ), expected)

    def test_integrated_home_has_no_syntax_socket_policy(self):
        config = json.loads(run(
            "nix", "eval", "--json", "--no-update-lock-file",
            "path:.#nixosConfigurations.pang14.config.home-manager.users.kyleh",
            "--apply", """c: {
              profile = c.programs.bash.profileExtra;
              tmuxEnabled = c.programs.tmux.enable;
              tmux = c.programs.tmux.extraConfig;
            }""", cwd=ROOT,
        ))
        self.assertTrue(config["tmuxEnabled"])
        self.assertNotIn("exec tmux", config["profile"])
        self.assertNotIn("ssh-agent.socket", config["profile"])
        self.assertNotIn("SSH_AUTH_SOCK", config["tmux"])
        self.assertNotIn("SSH_AGENT_PID", config["tmux"])
        self.assertNotIn("set-hook", config["tmux"])

    def test_tmux_stable_socket(self):
        config = self.directory / "tmux.conf"
        # Exercise the generated extra config without launching theme plugins.
        config.write_text(self.config["tmux"])
        self.assertIn(self.config["tmux"].strip(), self.config["generatedTmux"])
        socket = self.directory / "tmux.sock"

        def tmux(*args):
            return run("tmux", "-S", str(socket), *args, env=self.env)

        def stop():
            subprocess.run(["tmux", "-S", str(socket), "kill-server"],
                           env=self.env, capture_output=True, timeout=10)

        self.addCleanup(stop)
        tmux("-f", str(config), "new-session", "-d", "-s", "fixture",
             "bash --noprofile --norc")
        stable = f"SSH_AUTH_SOCK={self.directory}/ssh-agent.socket"
        self.assertEqual(tmux("show-environment", "-g", "SSH_AUTH_SOCK").strip(), stable)
        self.assertEqual(tmux("show-environment", "-t", "fixture", "SSH_AUTH_SOCK").strip(), stable)
        self.assertNotIn("SSH_AUTH_SOCK", tmux("show-options", "-gv", "update-environment"))
        self.assertNotIn("SSH_AGENT_PID", tmux("show-environment", "-g"))

        def pane_environment(pane, name):
            output = self.directory / name
            tmux("send-keys", "-t", pane,
                 'printf "%s|%s" "$SSH_AUTH_SOCK" "${SSH_AGENT_PID-unset}" > '
                 + shlex.quote(str(output)), "Enter")
            deadline = time.monotonic() + 5
            while not output.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertEqual(output.read_text(), f"{self.directory}/ssh-agent.socket|unset")

        pane = tmux("display-message", "-p", "-t", "fixture", "#{pane_id}").strip()
        pane_environment(pane, "before")
        tmux("set-environment", "-t", "fixture", "SSH_AUTH_SOCK", "stale")
        tmux("set-environment", "-t", "fixture", "SSH_AGENT_PID", "456")
        master, slave = pty.openpty()
        client = subprocess.Popen(
            ["tmux", "-S", str(socket), "attach-session", "-t", "fixture"],
            stdin=slave, stdout=slave, stderr=slave, env=self.env,
        )
        os.close(slave)
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.05)[0]:
                    os.read(master, 65536)
                if tmux("show-environment", "-t", "fixture", "SSH_AUTH_SOCK").strip() == stable:
                    break
            self.assertEqual(tmux("show-environment", "-t", "fixture", "SSH_AUTH_SOCK").strip(), stable)
            self.assertNotIn("SSH_AGENT_PID", tmux("show-environment", "-t", "fixture"))
            tmux("detach-client", "-s", "fixture")
            client.wait(timeout=5)
        finally:
            if client.poll() is None:
                client.terminate()
                client.wait(timeout=5)
            os.close(master)
        pane_environment(pane, "after")
        new_pane = tmux("new-window", "-d", "-P", "-F", "#{pane_id}", "-t", "fixture",
                        "bash --noprofile --norc").strip()
        pane_environment(new_pane, "new")


if __name__ == "__main__":
    unittest.main()
