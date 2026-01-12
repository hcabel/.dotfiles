import os
import sys
import re
import time
import shutil
import subprocess
from datetime import datetime
from typing import List, Optional, Tuple, Set, Callable
from dataclasses import dataclass, field
import urllib.request
import urllib.error
import json

AIVE_ROOT = os.path.expanduser(os.getenv("AIVE_ROOT", "~/aive"))
STACK_ROOT = os.path.expanduser(os.getenv("STACK_ROOT", "~/stack"))
DB_URL = os.getenv("DATABASE_URL", "postgresql://aive-owner:aive-owner@postgres:5432/aive")

@dataclass
class DeployState:
    ticket_id: str
    target_apps: List[str]
    version_args: List[str]
    tags: List[str] = field(default_factory=list)
    requires_db_update: bool = False
    db_backup_path: Optional[str] = None

class PipelineError(Exception):
    pass

class StepSkipped(Exception):
    pass

class PipelineAborted(Exception):
    pass

class PipelineUI:
    def __init__(self, steps: List[str]):
        self.steps = steps
        self.total = len(steps)
        self.current = 0
        self.step_lines = 0
        self._draw_pending()

    def _draw_pending(self, rewind: bool = True):
        pending = [f" ⏳ {self.steps[i]}" for i in range(self.current + 1, self.total)]
        if not pending:
            return

        sys.stdout.write("\n".join(pending) + "\n")

        if rewind:
            sys.stdout.write(f"\033[{len(pending)}A")
        sys.stdout.flush()

    def _clear_pending(self):
        sys.stdout.write("\033[J")
        sys.stdout.flush()

    def print(self, text: str, end: str = "\n"):
        self._clear_pending()
        width = shutil.get_terminal_size().columns
        lines = text.replace('\t', '    ').split('\n')

        for i, line in enumerate(lines):
            if len(line) >= width:
                lines[i] = line[:width - 4] + "..."

        final_text = "\n".join(lines)
        sys.stdout.write(final_text + end)
        self.step_lines += final_text.count('\n') + end.count('\n')
        self._draw_pending()

    def set_running(self):
        self._clear_pending()
        self.step_lines = 0
        sys.stdout.write(f"🔄 \033[1m{self.steps[self.current]}\033[0m\n")
        self.step_lines += 1
        self._draw_pending()

    def set_success(self):
        self._clear_pending()
        if self.step_lines > 0:
            sys.stdout.write(f"\033[{self.step_lines}A")

        sys.stdout.write(f"\r✅ \033[1m{self.steps[self.current]}\033[0m\033[K")

        if self.step_lines > 0:
            sys.stdout.write(f"\033[{self.step_lines}B")

        self.current += 1
        self._draw_pending()

    def set_skipped(self, message: str = ""):
        self._clear_pending()
        if self.step_lines > 0:
            sys.stdout.write(f"\033[{self.step_lines}A")
        suffix = f":\033[0m {message}" if message else "\033[0m"
        sys.stdout.write(f"\r⏭️  \033[1m{self.steps[self.current]} skipped{suffix}\033[K")
        if self.step_lines > 0:
            sys.stdout.write(f"\033[{self.step_lines}B")
        self.current += 1
        self._draw_pending()

    def set_failed(self, reason: str):
        self._clear_pending()
        if self.step_lines > 0:
            sys.stdout.write(f"\033[{self.step_lines}A")
        sys.stdout.write(f"\r❌ \033[1;31m{self.steps[self.current]} failed:\033[0m {reason}\033[K\n")
        if self.step_lines > 0:
            sys.stdout.write(f"\033[{self.step_lines - 1}B")

        # Draw the pending steps one last time, leaving the cursor at the bottom
        self._draw_pending(rewind=False)

    def set_aborted(self, message: str):
        self._clear_pending()
        sys.stdout.write(f"\n⏸️  \033[1mDeployment Paused:\033[0m {message}\n")

        # Draw the pending steps one last time, leaving the cursor at the bottom
        self._draw_pending(rewind=False)

    def prompt(self, text: str) -> bool:
        self._clear_pending()
        sys.stdout.write(text + " [y/N]: ")
        sys.stdout.flush()

        ans = input()
        self.step_lines += 1
        self._draw_pending()
        return bool(re.match(r'(?i)^y(es)?$', ans))

class Pipeline:
    def __init__(self, state: DeployState):
        self.state = state
        self.steps: List[Tuple[str, Callable[[DeployState, PipelineUI], None]]] = []
        self.ui = None

    def add_step(self, name: str, func: Callable[[DeployState, PipelineUI], None]):
        self.steps.append((name, func))

    def run(self):
        self.ui = PipelineUI([name for name, _ in self.steps])

        for _, func in self.steps:
            self.ui.set_running()
            try:
                func(self.state, self.ui)
                self.ui.set_success()
            except StepSkipped as e:
                self.ui.set_skipped(str(e))
            except PipelineAborted as e:
                self.ui.set_aborted(str(e))
                sys.exit(0)
            except PipelineError as e:
                self.ui.set_failed(str(e))
                sys.exit(1)
            except Exception as e:
                self.ui.set_failed(f"Unexpected error: {str(e)}")
                sys.exit(1)

def run_cmd(cmd: List[str], cwd: Optional[str] = None, capture: bool = False, ui: Optional[PipelineUI] = None) -> subprocess.CompletedProcess:
    if ui:
        process = subprocess.Popen(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        stdout_lines = []
        for line in process.stdout:
            clean = line.rstrip('\n')
            ui.print("   " + clean)
            stdout_lines.append(clean)
        process.wait()
        return subprocess.CompletedProcess(process.args, process.returncode, "\n".join(stdout_lines), "")

    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=capture)

# ---------------------------------------------------------
# PIPELINE TASKS (Isolated Business Logic)
# ---------------------------------------------------------

def validate_environment(state: DeployState, ui: PipelineUI):
    os.chdir(AIVE_ROOT)
    if run_cmd(["git", "branch", "--show-current"], capture=True).stdout.strip() != "main":
        raise PipelineError("Must be on 'main' branch to deploy.")

    existing_tags = run_cmd(["git", "tag", "--points-at", "HEAD"], capture=True).stdout.splitlines()
    for app in state.target_apps:
        for tag in existing_tags:
            if re.match(f"^{app}-v", tag):
                raise PipelineError(f"'{app}' is already tagged on this commit as '{tag}'.")

def generate_auto_tags(state: DeployState, ui: PipelineUI):
    current_level, current_apps = "", []

    for arg in state.version_args:
        if re.match(r'^(patch|minor|major)$', arg):
            if current_level and current_apps:
                res = run_cmd([os.path.join(AIVE_ROOT, "tools/auto-tag"), current_level] + current_apps, cwd=AIVE_ROOT, capture=True)
                if res.returncode != 0:
                    raise PipelineError("Auto-tag failed.")
                state.tags.extend(res.stdout.strip().splitlines())
            current_level, current_apps = arg, []
        else:
            current_apps.append(arg)

    if current_level and current_apps:
        res = run_cmd([os.path.join(AIVE_ROOT, "tools/auto-tag"), current_level] + current_apps, cwd=AIVE_ROOT, capture=True)
        if res.returncode != 0:
            raise PipelineError("Auto-tag failed.")
        state.tags.extend(res.stdout.strip().splitlines())

    if not state.tags:
        raise PipelineError("No tags generated.")

    suspicious = [t for t in state.tags if re.search(r'-(v1\.0\.0|v0\.1\.0|v0\.0\.1)$', t)]
    if suspicious:
        ui.print("   👀 Suspicious tags detected (possible typo?):")
        for st in suspicious:
            ui.print(f"      {st} ⚠️")

        if not ui.prompt("   Is this expected?"):
            for t in state.tags:
                run_cmd(["git", "tag", "-d", t], capture=True)
            raise PipelineError("Aborted by user due to suspicious tags.")

    for t in state.tags:
        ui.print(f"   {t}")

def push_tags_to_remote(state: DeployState, ui: PipelineUI):
    for i in range(0, len(state.tags), 3):
        chunk = state.tags[i:i+3]
        if run_cmd(["git", "push", "origin", "tag"] + chunk, cwd=AIVE_ROOT, ui=ui).returncode != 0:
            raise PipelineError("Failed to push tags to remote origin.")

def check_and_prepare_database(state: DeployState, ui: PipelineUI):
    diff = run_cmd(["git", "diff", "HEAD~1", "HEAD", "--name-only"], capture=True).stdout
    requires_cli = bool(re.search(r'src/aive-cli/.*/service\.go', diff))
    requires_sql = 'src/sql/schema_aggregate.sql' in diff

    if not (requires_cli or requires_sql):
        raise StepSkipped("No SQL schema or CLI migration changes detected.")

    state.requires_db_update = True
    ui.print("   💽 SQL schema changes detected. Preparing database...")

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    state.db_backup_path = f"/tmp/aive_db_backup_{ts}.sql"
    with open(state.db_backup_path, "w") as f:
        ui._clear_pending()
        res = subprocess.run(["pg_dump", "--clean", "--if-exists", DB_URL], stdout=f, stderr=subprocess.PIPE, text=True)
        for line in res.stderr.splitlines():
            sys.stdout.write("   " + line + "\n")
            ui.step_lines += 1
        ui._draw_pending()

    if res.returncode != 0:
        raise PipelineError("Database backup failed!")

    if requires_sql:
        ui.print("   🏗️ Running SQL migrations...")
        if run_cmd(["migrate", "-database", f"{DB_URL}?sslmode=disable", "-path", "./src/sql", "up"], cwd=AIVE_ROOT, ui=ui).returncode != 0:
            raise PipelineError("SQL Migration failed.")
        ui.print("   ✅ Migration completed successfully.")

    if requires_cli:
        ui.print("   🏗️ CLI migrations detected. Please run the CLI commands manually.")
        if not ui.prompt("   Have you completed the CLI migrations?"):
            raise PipelineError("Deployment aborted pending CLI migrations.")

def update_stack_repository(state: DeployState, ui: PipelineUI):
    target_dir = os.path.join(STACK_ROOT, "k8s/staging-main")
    if not os.path.isdir(STACK_ROOT):
        raise PipelineError("Stack repository not found.")

    if run_cmd(["git", "status", "--porcelain"], cwd=STACK_ROOT, capture=True).stdout.strip():
        run_cmd(["git", "stash"], cwd=STACK_ROOT, ui=ui)

    if run_cmd(["git", "pull"], cwd=STACK_ROOT, ui=ui).returncode != 0:
        raise PipelineError("Git pull failed on stack repo.")

    for tag in state.tags:
        match = re.match(r'^(.*)-(v[0-9].*)$', tag)
        if not match:
            continue

        app_name = "analyser-processor" if match.group(1) == "analyser-procesor" else match.group(1)

        if run_cmd(["kustomize", "edit", "set", "image", f"aivetech/{app_name}:{match.group(2)}"], cwd=target_dir).returncode != 0:
            raise PipelineError(f"Failed to update kustomize for {app_name}.")

    run_cmd(["git", "add", "k8s/staging-main/kustomization.yaml"], cwd=STACK_ROOT)
    if run_cmd(["git", "commit", "-m", f"{state.ticket_id} {' '.join(state.tags)}"], cwd=STACK_ROOT, ui=ui).returncode != 0:
        raise PipelineError("Failed to commit changes to stack repository.")

def review_kubernetes_diff(state: DeployState, ui: PipelineUI):
    res = run_cmd(["kubectl", "diff", "-k", "k8s/staging-main/"], cwd=STACK_ROOT, capture=True)
    for line in res.stdout.splitlines():
        if re.match(r'^(\+|-)', line):
            ui.print("   " + line)

    if not ui.prompt("   🤔 Do you want to apply this diff?"):
        raise PipelineAborted("Changes are committed but not applied.")

def wait_for_github_actions(state: DeployState, ui: PipelineUI):
    if shutil.which("gh") is None:
        raise PipelineError("GitHub CLI ('gh') is not installed or not in PATH.")

    ui.print(f"   ⏳ Waiting for 'publish' workflows for {len(state.tags)} tags...")
    ui.step_lines = 1

    pending_tags = state.tags.copy()
    ready_tags: Set[str] = set()

    while pending_tags:
        # Increase limit to 100 to comfortably cover 10+ packages and potential retries.
        # headBranch contains the tag name for tag-triggered workflows.
        gh_cmd = [
            "gh", "-R", "aivetech/aive", "run", "list",
            "-w", "publish",
            "--json", "status,conclusion,headBranch,name",
            "--limit", "100"
        ]
        gh_res = run_cmd(gh_cmd, capture=True)

        if gh_res.returncode != 0:
            ui._clear_pending()
            if ui.step_lines > 0:
                sys.stdout.write(f"\033[{ui.step_lines}A")
            sys.stdout.write(f"\r\033[K   ⚠️  'gh' CLI error. Retrying...\n")
            ui._draw_pending()
            time.sleep(5)
            continue

        try:
            runs = json.loads(gh_res.stdout)
        except json.JSONDecodeError:
            time.sleep(5)
            continue

        ui._clear_pending()
        if ui.step_lines > 0:
            sys.stdout.write(f"\033[{ui.step_lines}A")

        new_pending = []
        status_lines = []

        for tag in state.tags:
            if tag in ready_tags:
                status_lines.append(f"   ✅ {tag} (Success)")
                continue

            # Find the most recent run for this specific tag.
            # Because `gh` returns newest first, the first match is the correct one.
            tag_run = next((run for run in runs if run.get("headBranch") == tag), None)

            if not tag_run:
                status_lines.append(f"   ⏳ {tag} (Waiting to initialize...)")
                new_pending.append(tag)
                continue

            status = tag_run.get("status")
            conclusion = tag_run.get("conclusion")

            if status == "completed":
                if conclusion == "success":
                    status_lines.append(f"   ✅ {tag} (Success)")
                    ready_tags.add(tag)
                else:
                    # Draw current status, then immediately raise the failure
                    output = "\n".join([f"\r\033[K{line}" for line in status_lines])
                    sys.stdout.write(output + f"\n\r\033[K   ❌ {tag} (Failed: {conclusion})\n")
                    ui._draw_pending(rewind=False)
                    raise PipelineError(f"Workflow for '{tag}' failed with conclusion: {conclusion}")
            else:
                status_lines.append(f"   ⏳ {tag} ({status}...)")
                new_pending.append(tag)

        # Output the updated lines
        output = "\n".join([f"\r\033[K{line}" for line in status_lines]) + "\n"
        sys.stdout.write(output)

        ui.step_lines = len(status_lines)
        ui._draw_pending()

        pending_tags = new_pending
        if pending_tags:
            time.sleep(10)

def wait_for_docker_images(state: DeployState, ui: PipelineUI):
    pending_tags = state.tags.copy()
    ready_tags: Set[str] = set()

    for t in state.tags:
        ui.print(f"      ⏳ {t}")

    while pending_tags:
        new_pending = []

        sys.stdout.write(f"\033[{len(state.tags)}A")

        for t in state.tags:
            if t in ready_tags:
                sys.stdout.write(f"\r\033[K      ✅ {t}\n")
            else:
                image_tag = "aivetech/" + re.sub(r'-(v[0-9].*)$', r':\1', t)
                if subprocess.run(["docker", "manifest", "inspect", image_tag], capture_output=True).returncode == 0:
                    sys.stdout.write(f"\r\033[K      ✅ {t}\n")
                    ready_tags.add(t)
                else:
                    sys.stdout.write(f"\r\033[K      ⏳ {t}...\n")
                    new_pending.append(t)

        sys.stdout.flush()
        pending_tags = new_pending
        if pending_tags:
            time.sleep(1)

def apply_cluster(state: DeployState, ui: PipelineUI):
    res = run_cmd(["kubectl", "apply", "-k", "k8s/staging-main/"], cwd=STACK_ROOT, capture=True)
    if res.returncode != 0:
        raise PipelineError("kubectl apply failed.")

    for line in res.stdout.splitlines():
        if "unchanged" not in line:
            ui.print("   " + line)

def monitor_cluster(state: DeployState, ui: PipelineUI):
    grep_pattern = "|".join([re.sub(r'-v[0-9].*$', '', t) for t in state.tags])
    ui.print(f"   👀 Monitoring pods for: {grep_pattern}")
    time.sleep(5)

    prev_lines = 0
    while True:
        pods_res = subprocess.run(["kubectl", "get", "pods"], capture_output=True, text=True).stdout
        current_pods = [line for line in pods_res.splitlines() if re.search(grep_pattern, line)]

        lines = []
        lines.append("   ------------------------------------------------------")
        if not current_pods:
            lines.append("   ⏳ No matching pods found yet. Waiting for Kubernetes to schedule...")
        else:
            for line in current_pods:
                lines.append(f"   {line}")

            pending_pods = [p for p in current_pods if not re.search(r'\b(Running)\b', p)]
            if not pending_pods:
                lines.append("   ------------------------------------------------------")
                lines.append("   🎉 All updated pods are successfully Running!")

        current_lines = len(lines)

        ui._clear_pending()
        if prev_lines > 0:
            sys.stdout.write(f"\033[{prev_lines}A")

        clean_output = "\n".join([f"\r\033[K{line}" for line in lines]) + "\n"
        sys.stdout.write(clean_output)

        ui.step_lines += (current_lines - prev_lines)
        ui._draw_pending()

        if current_pods and not pending_pods:
            break

        prev_lines = current_lines
        time.sleep(1)

def main():
    args = sys.argv[1:]
    if len(args) < 3 or not re.match(r'^PF-[0-9]+$', args[0]) or not re.match(r'^(patch|minor|major)$', args[1]):
        print("⚠️  Usage: aivedeploy <ticket_id> [patch|minor|major] <service1> ...", file=sys.stderr)
        sys.exit(1)

    state = DeployState(
        ticket_id=args[0],
        version_args=args[1:],
        target_apps=[a for a in args[1:] if not re.match(r'^(patch|minor|major)$', a)]
    )

    pipeline = Pipeline(state)
    pipeline.add_step("Validate Environment", validate_environment)
    pipeline.add_step("Generate Auto-Tags", generate_auto_tags)
    pipeline.add_step("Push Tags to Remote", push_tags_to_remote)
    pipeline.add_step("Check & Prepare Database", check_and_prepare_database)
    pipeline.add_step("Update Stack Repository", update_stack_repository)
    pipeline.add_step("Review Kubernetes Diff", review_kubernetes_diff)
    # pipeline.add_step("Wait for Docker Images", wait_for_docker_images)
    pipeline.add_step("Wait for GitHub Actions", wait_for_github_actions)
    pipeline.add_step("Apply Cluster", apply_cluster)
    pipeline.add_step("Apply & Monitor Cluster", monitor_cluster)
    pipeline.run()

    if state.requires_db_update and state.db_backup_path:
        print("\n🧪 \033[1mDeployment complete. Please test the application.\033[0m")
        if pipeline.ui.prompt("   ⏪ Do you need to revert the database?"):
            print(f"   ⏪ Restoring from {state.db_backup_path}...")
            if run_cmd(["psql", DB_URL, "-f", state.db_backup_path], capture=True).returncode == 0:
                print("   ✅ Database restored.")
            else:
                print("   ❌ Database restore failed.")

if __name__ == "__main__":
    main()
