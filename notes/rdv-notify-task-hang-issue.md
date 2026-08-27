# rdv-notify: Task Hanging Issue Analysis

## Problem Summary

The `bin/rdv-notify` script's task handler section (lines 173-178) blocks indefinitely on `wait ${pid}` when a launched task fails in an undetermined way or hangs. This prevents the notification system from reporting the task status and eventually cleaning up.

**Location**: `bin/rdv-notify`, lines 173-178

```bash
"${task[@]}" &
pid=$!
echo "${pid} - ${tag}" > ${DAEMON_PIPE}
wait ${pid}  # <-- BLOCKS FOREVER IF TASK HANGS
code=${?}
exit
```

---

## Root Cause Analysis

1. **No timeout on `wait ${pid}`** (line 176): Bash's built-in `wait` has no timeout mechanism. If the task process hangs, the script blocks forever.

2. **Missing process monitoring**: No mechanism to detect if the task process has become unresponsive or a zombie process.

3. **Incomplete trap handling**: The `on_task_exit` trap (lines 130-140) is only triggered when the current process receives signals, but doesn't protect against a hung child process.

4. **No heartbeat/health check**: The daemon has no way to know if a task is still alive or responding.

---

## Design Goal

**The real issue is simple**: rdv-notify should not wait forever on a faulty command. Period.

**What we actually need**:

1. Do not wait ${pid} on hanging/zombi/dead process
2. Kill the task if it hangs
3. Report the status
4. Move on

**What we don't need to solve**:

- Process tree cleanup for orphaned children
- Recursive killing of entire process hierarchies
- Process group management

The task's responsibility is to exit cleanly. If it doesn't, that's a bug in the task, not in rdv-notify. rdv-notify is a notification system, not a process supervisor.

---

## Alternative Approaches

### Approach 1: Timeout-aware wait with background monitoring

**Strategy**: Use a background monitoring process that kills the task if it doesn't exit within a reasonable time.

**Implementation**:

```bash
# Add after line 176
TASK_TIMEOUT=300  # 5 minutes timeout
(
    sleep "$TASK_TIMEOUT"
    if kill -0 "$pid" 2>/dev/null; then
        echo "Task $tag (PID $pid) timed out after ${TASK_TIMEOUT}s" >&2
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        kill -9 "$pid" 2>/dev/null
    fi
) &
monitor_pid=$!

wait "$pid" 2>/dev/null
code=$?
kill "$monitor_pid" 2>/dev/null
```

**Trade-offs**:
| Aspect | Assessment |
|--------|------------|
| Complexity | Medium |
| Reliability | High |
| Resource overhead | One additional background process per task |
| New issue | Need to clean up monitor process on normal exit |

---

### Approach 2: Non-blocking wait with timeout loop

**Strategy**: Replace blocking `wait` with a loop that checks process status periodically.

**Implementation**:

```bash
# Replace lines 176-177 with:
TASK_TIMEOUT=300
interval=1
elapsed=0
while kill -0 "$pid" 2>/dev/null && ((elapsed < TASK_TIMEOUT)); do
    sleep $interval
    ((elapsed += interval))
done

if kill -0 "$pid" 2>/dev/null; then
    echo "Task $tag (PID $pid) timed out" >&2
    kill -TERM "$pid" 2>/dev/null
    sleep 1
    kill -9 "$pid" 2>/dev/null
    code=124  # timeout exit code
else
    wait "$pid" 2>/dev/null
    code=$?
fi
```

**Trade-offs**:
| Aspect | Assessment |
|--------|------------|
| Complexity | Low |
| Reliability | Medium (polling interval affects responsiveness) |
| Resource overhead | Minimal |
| New issue | Potential race condition if process exits between check and kill |

---

### Approach 3: Process group monitoring with external tool

**Strategy**: Use process groups to monitor and clean up entire process trees.

**Key Concepts**:

| Command | Meaning |
|---------|---------|
| `set -m` | Enable job control, creates process groups |
| `ps -o pgid= -p $pid` | Get process group ID for a PID |
| `wait -n $pid` | Wait for specific PID (Bash 4.3+) |
| `kill -$pgid` | Send signal to entire process group |
| `kill -0 -$pgid` | Check if process group exists |

**Implementation**:

```bash
TASK_TIMEOUT=300  # 5 minutes

# Enable job control for process groups
set -m

# Launch task in its own process group
"${task[@]}" &
pid=$!
pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')

# Store for cleanup
echo "${pid} - ${tag}" > "${DAEMON_PIPE}"

# Background monitor with timeout
(
    sleep "$TASK_TIMEOUT"
    if kill -0 -"$pgid" 2>/dev/null; then
        echo "Task $tag (PGID $pgid) timed out" >&2
        kill -TERM -"$pgid" 2>/dev/null
        sleep 2
        kill -9 -"$pgid" 2>/dev/null
    fi
) &
monitor_pid=$!

# Wait for the specific process (not the group, to get correct exit code)
wait "$pid" 2>/dev/null
code=$?

# Cleanup monitor
kill "$monitor_pid" 2>/dev/null

# Ensure process group is fully cleaned up
if kill -0 -"$pgid" 2>/dev/null; then
    kill -9 -"$pgid" 2>/dev/null
fi
```

**Visual Flow**:

```
Without Process Groups:         With Process Groups:
┌────────────────┐              ┌─────────────────┐ 
│   rdv-notify   │              │   rdv-notify    │ 
│       │        │              │       │         │ 
│       ▼        │              │       ▼         │ 
│   task PID     │              │  ┌──────────┐   │ 
│       │        │              │  │ Process  │   │ 
│       ▼        │              │  │  Group   │   │ 
│  child1 PID    │              │  │ ┌──────┐ │   │ 
│       │        │              │  │ │ task │ │   │ 
│       ▼        │              │  │ └──────┘ │   │ 
│  child2 PID    │              │  │ ┌──────┐ │   │ 
└────────────────┘              │  │ │child1│ │   │ 
                                │  │ └──────┘ │   │ 
Cannot reliably kill            │  │ ┌──────┐ │   │ 
entire tree                     │  │ │child2│ │   │ 
                                │  │ └──────┘ │   │ 
                                │  └──────────┘   │ 
                                └─────────────────┘ 
                                                    
                                 kill -$pgid        
                                 sends to ALL       
```

**Trade-offs**:
| Aspect | Assessment |
|--------|------------|
| Complexity | Medium |
| Reliability | High |
| Resource overhead | Minimal |
| New issue | `wait -n` requires Bash 4.3+, process group ID stability concerns |

**Limitations**:
- `wait -n` requires Bash 4.3+ (not available in older versions)
- Process group ID stability concerns (see detailed analysis below)
- Some processes ignore SIGTERM - still need SIGKILL fallback
- Race conditions possible between check and kill

---

### Process Group ID Stability Analysis

**Assertion**: "Process group ID might change if task spawns its own job control"

**Research Findings**: This assertion is **PARTIALLY INCORRECT** but highlights a real concern about process tree cleanup. Here's the detailed analysis:

#### What Actually Happens with Process Groups

**Key POSIX/Linux behavior**:

1. **Child processes inherit parent's PGID**:
   - A child created via `fork()` inherits its parent's process group ID
   - The PGID is preserved across `execve()` calls
   - Source: `setpgid(2)` man page: "A child created via fork(2) inherits its parent's process group ID. The PGID is preserved across an execve(2)."

2. **Process group changes are restricted**:
   - A process can only change its own PGID or its children's PGID **before exec**
   - After `exec()`, attempting to change PGID returns `EACCES` error
   - Source: POSIX standard: "Since it would be confusing to an application to have its process group change after it began executing (that is, after exec), and because the child process would already have adjusted its process group before this, the [EACCES] error was added to disallow this."

3. **Process group creation rules**:
   - `setpgid()` only allows:
     - Joining an existing process group in the same session
     - Creating a new process group where PGID equals the process's own PID
   - Source: POSIX standard: "To provide tighter security, setpgid() only allows the calling process to join a process group already in use inside its session or create a new process group whose process group ID was equal to its process ID."

#### The Real Concern: Process Tree Cleanup

The assertion conflates two different issues:

**Issue 1: Parent task's PGID changes** (INCORRECT)
- The parent task's PGID will NOT change after it starts executing
- Once we capture `pgid=$(ps -o pgid= -p "$pid")`, it remains stable for the parent process
- The parent cannot change its own PGID after `exec()`

**Issue 2: Child processes in different process groups** (CORRECT CONCERN)
- If the task is a shell script with job control enabled (`set -m`), it can create NEW process groups for its child processes
- These child processes will have DIFFERENT PGIDs than the parent task
- Example: A bash script running `command1 | command2` with job control creates separate process groups for each command in the pipeline

#### Visual Example

```
Scenario: Task is a bash script with job control
┌─────────────────────────────────────────────────┐
│ rdv-notify (PGID: 1000)                         │
│   │                                             │
│   ▼                                             │
│ task script (PGID: 2000) ← We capture this PGID │
│   │                                             │
│   ├──► child1 (PGID: 2000) ← Same group         │
│   │                                             │
│   └──► child2 (PGID: 3000) ← DIFFERENT group!   │
│         (if script uses job control)            │
└─────────────────────────────────────────────────┘

When we run: kill -TERM -2000
- task script receives SIGTERM ✓
- child1 receives SIGTERM ✓
- child2 does NOT receive SIGTERM ✗ (different PGID)
```

#### Why This Matters for Cleanup

When the task hangs:
1. We capture PGID of the task process (e.g., 2000)
2. Task spawns child processes with different PGIDs (e.g., 3000)
3. Task hangs or exits abnormally
4. We try to kill process group 2000
5. Child processes in group 3000 continue running
6. Orphaned processes may keep resources locked

#### Solutions for Process Tree Cleanup

**Solution 1: Recursive process tree killing** (RECOMMENDED)

```bash
# Kill entire process tree recursively
kill_process_tree() {
    local pid=$1
    local signal=${2:-TERM}
    
    # Get all descendant PIDs
    local children=$(pgrep -P "$pid" 2>/dev/null)
    
    # Kill children first (bottom-up)
    for child in $children; do
        kill_process_tree "$child" "$signal"
    done
    
    # Kill the parent
    kill -"$signal" "$pid" 2>/dev/null
}

# Usage
kill_process_tree "$pid" TERM
sleep 2
kill_process_tree "$pid" KILL
```

**Solution 2: Use process group AND recursive killing**

```bash
# Kill process group and all orphaned children
kill_process_group_and_children() {
    local pgid=$1
    local signal=${2:-TERM}
    
    # Kill entire process group
    kill -"$signal" -"$pgid" 2>/dev/null
    
    # Find and kill any orphaned children
    # (processes with PPID in the group but different PGID)
    local orphans=$(ps -eo pid,ppid,pgid | awk -v pgid="$pgid" '
        $3 != pgid && $2 in seen { print $1 }
        { seen[$2] = 1 }
    ')
    
    for orphan in $orphans; do
        kill -"$signal" "$orphan" 2>/dev/null
    done
}
```

**Solution 3: Use `setsid` to create a new session**

```bash
# Create a new session - all children will be in the same session
setsid bash -c '
    exec "${task[@]}"
' &
pid=$!
pgid=$(ps -o pgid= -p "$pid" | tr -d ' ')

# All descendants are now in the same session
# Can use: kill -TERM -- -"$pgid"
```

**Solution 4: Monitor with `pstree` for complete tree view**

```bash
# Get full process tree
pstree -p "$pid"

# Kill entire tree using pkill with tree option
pkill -TERM -P "$pid"  # Kill all children
kill -TERM "$pid"       # Kill parent
```

#### Recommendation

For the `rdv-notify` use case, **Solution 1 (Recursive process tree killing)** is most reliable because:

1. **Handles all cases**: Works regardless of process group structure
2. **No job control dependency**: Doesn't require `set -m` or process groups
3. **Deterministic**: Guarantees cleanup of entire process tree
4. **Simple implementation**: Easy to understand and debug

**Implementation in rdv-notify**:

```bash
# Add this function to the task handler section
kill_task_tree() {
    local pid=$1
    local signal=${2:-TERM}
    
    # Get all child PIDs recursively
    local children=$(pgrep -P "$pid" 2>/dev/null)
    
    # Kill children first (bottom-up to avoid orphans)
    for child in $children; do
        kill_task_tree "$child" "$signal"
    done
    
    # Kill the parent
    kill -"$signal" "$pid" 2>/dev/null
}

# In the timeout handler:
(
    sleep "$TASK_TIMEOUT"
    if kill -0 "$pid" 2>/dev/null; then
        echo "Task $tag (PID $pid) timed out" >&2
        kill_task_tree "$pid" TERM
        sleep 2
        kill_task_tree "$pid" KILL
    fi
) &
```

**Alternative without `set -m`**:

If you can't enable job control (it affects terminal behavior), use a wrapper script:

```bash
# Wrapper approach - create group manually
setsid bash -c '
    exec "${task[@]}"
' &
pid=$!
pgid=$(ps -o pgid= -p "$pid" | tr -d ' ')

# Now monitor $pgid...
```

---

### Approach 4: Robust signal-based cleanup

**Strategy**: Enhance signal handling to ensure cleanup happens regardless of task state.

**Implementation**:

```bash
# Enhanced on_task_exit function
on_task_exit() {
    local exit_code=${1:-$?}
    
    # Ensure we always send status to daemon
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null
        sleep 1
        kill -9 "$pid" 2>/dev/null
        code=137  # SIGKILL
    fi
    
    if [[ -n "${tag:-}" ]]; then
        echo "${pid} ${code:-$exit_code} ${tag}" > "${DAEMON_PIPE}"
    fi
    
    trap - INT TERM EXIT
    return "${code:-$exit_code}"
}
```

**Trade-offs**:
| Aspect | Assessment |
|--------|------------|
| Complexity | Medium |
| Reliability | High |
| Resource overhead | Minimal |
| New issue | May not solve fundamental hang issue if process ignores signals |

---

## Debugging Tools

### 1. Add process monitoring debug output

```bash
# Add before wait in task handler
echo "DEBUG: Task $tag PID $pid started at $(date)" >&2
echo "DEBUG: Waiting for PID $pid" >&2

# Add after wait
echo "DEBUG: PID $pid exited with code $?" >&2
```

### 2. Create a test case to reproduce the issue

```bash
#!/bin/bash
# test_hang.sh - Simulate a hanging task
echo "Starting hanging task..."
sleep 1
echo "Entering infinite loop..."
while true; do
    sleep 1
done
```

### 3. Monitor process state during execution

```bash
# Add in a loop during wait
while kill -0 "$pid" 2>/dev/null; do
    echo "PID $pid state: $(cat /proc/$pid/status 2>/dev/null | grep State)"
    sleep 5
done
```

### 4. Use system tools for debugging

```bash
# Check process state
ps -p $pid -o pid,ppid,stat,cmd

# Check file descriptors
ls -la /proc/$pid/fd

# Check signals
cat /proc/$pid/status | grep Sig
```

---

## Recommended Solution

### Approach 5: Process Health Detection with Job Control (RECOMMENDED)

**Strategy**: Monitor process state using POSIX-compatible `ps` command and use bash job control for automatic process group cleanup. No arbitrary timeouts - detect actual problems.

**Key Insight**: Instead of guessing when to kill a task (timeout), detect when a task is actually unhealthy (zombie, stuck on I/O, stopped) and kill it automatically.

**Implementation**:

```bash
set -m  # Enable job control - each & gets its own process group

is_process_healthy() {
    local pid=$1
    local state=$(ps -o state= -p "$pid" 2>/dev/null | tr -d ' ')
    
    case "$state" in
        Z*) return 1  # Zombie - dead but not reaped
        D*) return 1  # Uninterruptible sleep - stuck on I/O
        T*) return 1  # Stopped - suspended
        S*|R*) return 0  # Sleeping or Running - healthy
        *) return 1  # Unknown or dead
    esac
}

# Launch task - job control puts it in its own process group
"${task[@]}" &
pid=$!
pgid=$pid  # With job control, process group leader = first PID

echo "${pid} - ${tag}" > "${DAEMON_PIPE}"

# Monitor for unhealthy state
while kill -0 "$pid" 2>/dev/null; do
    if ! is_process_healthy "$pid"; then
        echo "Task $tag unhealthy, killing process group" >&2
        kill -TERM -"$pgid" 2>/dev/null  # Kill entire group
        sleep 2
        kill -9 -"$pgid" 2>/dev/null    # Force if needed
        break
    fi
    sleep 2
done

wait "$pid" 2>/dev/null
code=$?
```

**Why this is the best approach**:

| Aspect | Assessment |
|--------|------------|
| Detection method | State-based (POSIX `ps` command) |
| Cleanup method | Job control process groups |
| Arbitrary timeouts | None - detect actual problems |
| POSIX compatibility | High - uses standard `ps -o state=` |
| Complexity | Low - simple state check + kill |
| Resource overhead | Minimal - no background monitors |
| Reliability | High - catches zombie, I/O hang, stopped |

**What it catches automatically**:
- **Zombie (Z)**: Process exited but parent didn't reaped it
- **Uninterruptible sleep (D)**: Stuck on I/O (disk, network, etc.)
- **Stopped (T)**: Suspended and never resumed

**What it doesn't catch** (and shouldn't):
- Infinite loops in R/S state - that's a task bug, not rdv-notify's problem
- Tasks that are "slow but working" - no arbitrary timeout killing healthy tasks

**Complementary: Hardened on_task_exit() trap**

The health detection approach works best when combined with a robust trap handler. This ensures cleanup happens regardless of how the process exits:

```bash
# Enhanced on_task_exit function
on_task_exit() {
    local exit_code=$?
    
    # If we have a task running, ensure it's cleaned up
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
        # Task still running - kill process group
        local pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')
        
        if [[ -n "$pgid" ]] && kill -0 -"$pgid" 2>/dev/null; then
            kill -TERM -"$pgid" 2>/dev/null
            sleep 1
            kill -9 -"$pgid" 2>/dev/null
        else
            kill -TERM "$pid" 2>/dev/null
            sleep 1
            kill -9 "$pid" 2>/dev/null
        fi
        
        code=137  # SIGKILL
    fi
    
    # Always report status to daemon
    if [[ -n "${tag:-}" ]]; then
        echo "${pid:-} ${code:-$exit_code} ${tag}" > "${DAEMON_PIPE}"
    fi
    
    trap - INT TERM EXIT
    return "${code:-$exit_code}"
}
trap on_task_exit INT TERM EXIT
```

**Why combine both approaches**:
- **Health detection**: Catches zombie/I/O hang/stopped states during normal operation
- **Hardened trap**: Ensures cleanup when script receives signals (SIGTERM, SIGINT, EXIT)
- **Defense in depth**: Multiple layers of protection against hanging

**Alternative approaches** (if job control not desired):

**Approach 1: Timeout-aware wait with background monitoring**
- Use when: Need deterministic cleanup regardless of process state
- Trade-off: Arbitrary timeout may kill healthy tasks

**Implementation priority**:
1. **Immediate fix (15 minutes)**: Implement Approach 5 with health detection + hardened trap
2. **Short-term improvement (30 minutes)**: Add logging/debugging capabilities
3. **Testing (30 minutes)**: Validate with test cases below

---

## Test Cases to Validate

### Health Detection Tests

```bash
# Test 1: Zombie process detection
# Create a zombie by having parent exit without reaping child
./test_zombie.sh &
pid=$!
# Verify is_process_healthy returns 1 for zombie state

# Test 2: Uninterruptible sleep detection
# Simulate D state (e.g., stuck on NFS mount)
./test_io_hang.sh &
pid=$!
# Verify is_process_healthy returns 1 for D state

# Test 3: Stopped process detection
# Stop a process with SIGSTOP
sleep 100 &
pid=$!
kill -STOP $pid
# Verify is_process_healthy returns 1 for T state
kill -CONT $pid  # Cleanup
```

### Process Cleanup Tests

```bash
# Test 4: Process group cleanup with job control
set -m
sleep 100 &
pid=$!
pgid=$pid  # With job control, PGID = PID
kill -TERM -"$pgid"
# Verify both parent and children in group are killed

# Test 5: Hardened trap on SIGTERM
# Start task, send SIGTERM to rdv-notify, verify cleanup
./rdv-notify "sleep 100" test_tag &
rdv_pid=$!
sleep 1
kill -TERM $rdv_pid
# Verify task is also killed

# Test 6: Hardened trap on normal exit
# Start task, let rdv-notify exit normally, verify cleanup
./rdv-notify "sleep 100" test_tag &
rdv_pid=$!
sleep 1
kill -TERM $rdv_pid  # Simulate normal exit
# Verify task is cleaned up
```

### Integration Tests

```bash
# Test 7: Multiple concurrent tasks
# Run 3 tasks simultaneously, verify all complete or get cleaned up
for i in 1 2 3; do
    ./rdv-notify "sleep $((i * 10))" "task_$i" &
done
wait

# Test 8: Task with child processes
# Task spawns children, verify entire group is cleaned up
./rdv-notify "bash -c 'sleep 100 & sleep 100 & wait'" test_tag &
pid=$!
sleep 1
kill -TERM $pid
# Verify all children are also killed

# Test 9: Rapid task completion
# Task completes before monitor loop runs
./rdv-notify "echo done" test_tag &
pid=$!
# Verify normal exit code is reported

# Test 10: Daemon restart while task running
# Start task, restart daemon, verify task is handled
./rdv-notify "sleep 100" test_tag &
task_pid=$!
sleep 1
tmux kill-server  # Restart daemon
# Verify task is cleaned up or daemon handles it
```

### Edge Cases

```bash
# Test 11: Task that ignores SIGTERM
# Task catches SIGTERM and continues
./rdv-verify "bash -c 'trap \"\" TERM; sleep 100'" test_tag &
pid=$!
sleep 1
# Verify SIGKILL is used after SIGTERM fails

# Test 12: Task exits immediately
# Task completes in < 1 second
./rdv-verify "true" test_tag &
pid=$!
# Verify immediate cleanup and status report

# Test 13: Task with no children
# Simple command without child processes
./rdv-verify "echo hello" test_tag &
pid=$!
# Verify basic functionality works
```

### Validation Checklist

- [ ] `is_process_healthy()` correctly identifies Z, D, T states
- [ ] `is_process_healthy()` returns 0 for S, R states
- [ ] Process group killed with `kill -TERM -"$pgid"` works
- [ ] Hardened `on_task_exit()` triggers on SIGTERM
- [ ] Hardened `on_task_exit()` triggers on SIGINT
- [ ] Hardened `on_task_exit()` triggers on EXIT
- [ ] Status reported to daemon pipe in all cases
- [ ] No zombie processes left after cleanup
- [ ] No orphaned children after cleanup
