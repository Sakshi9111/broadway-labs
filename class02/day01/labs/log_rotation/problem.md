# Problem: The Disk Is Filling Up

Linux for DevOps Engineers · Broadway Infosys · DevOps Training

> This file contains the **problem only**. Try to solve it on your own first. The step-by-step solution is in `solution.md`.

## Table of Contents

- [The situation](#the-situation)
- [Environment](#environment)
- [Rules](#rules)
- [Setup](#setup)
- [Your tasks](#your-tasks)
- [Hints](#hints)
- [Questions](#questions)

---

## The situation

It is 2 AM. Your monitoring system sends this alert:

```text
ALERT: root filesystem on prod-web-01 is almost full.
Applications may crash and logins may fail.
```

You are the on-call engineer. Your manager expects you to:

1. Find out **what** is using the disk.
2. Free space **safely**, without breaking the running application.
3. Explain why space sometimes does **not** come back after deleting a file.
4. Find out **why** the logs grew.
5. Make sure this **never happens again**.

**Safe simulation:** in real life the culprit could be 200 GB. In this lab the files are 200 MB and 50 MB, so nothing is at risk, but the method is identical.

## Rules

- Do **not** delete `/var/log/demoapp/debug.log` or `/var/log/demoapp/old.log`. They belong to a running application and the old log must stay available.
- Do **not** reboot the machine.
- Do **not** use `chmod 777` or `rm -rf` on anything outside `/var/log/demoapp`, `/tmp/app.log` and `/etc/logrotate.d/demoapp`.
- Show your commands and their output for every task. A task without evidence gets no marks.

---

## Setup

Run these commands once to create the situation.

### Large log files

```bash
sudo mkdir -p /var/log/demoapp
sudo fallocate -l 200M /var/log/demoapp/debug.log
sudo fallocate -l 50M /var/log/demoapp/old.log
```

If `fallocate` fails, use `dd` instead:

```bash
sudo dd if=/dev/zero of=/var/log/demoapp/debug.log bs=1M count=200
sudo dd if=/dev/zero of=/var/log/demoapp/old.log bs=1M count=50
```

### Application log

This creates 300 log lines. Every 7th line is an `ERROR`.

```bash
for i in $(seq 1 300); do
  if [ $((i%7)) -eq 0 ]; then
    echo "2026-11-18 10:00:$((i%60)) ERROR payment failed order=$i"
  else
    echo "2026-11-18 10:00:$((i%60)) INFO request $i ok"
  fi
done > /tmp/app.log
```

### Check the setup

```bash
ls -lh /var/log/demoapp
wc -l /tmp/app.log
```

You should see a 200 MB `debug.log`, a 50 MB `old.log` and `300 /tmp/app.log`.

---

## Your tasks

### Task 1: Measure the starting point

Record how much space is used on the root filesystem, in whole megabytes. You will compare against this number later.

**Evidence:** the command and your written number.

### Task 2: Find the biggest directory

Under `/var/log`, find which directory or file uses the most space. List the sizes in order, with the biggest at the bottom. Then look inside the biggest directory and list its contents with sizes.

**Evidence:** both commands and their output.

### Task 3: Find the large files

1. List every file bigger than **100 MB** under `/var/log`.
2. List every file bigger than **50 MB** under `/var/log`, showing the size of each file in a readable form.

**Evidence:** both commands and their output.

### Task 4: Free space safely

1. `debug.log` is being written by a running application. Free all the space it uses, **without deleting the file**.
2. `old.log` must stay available but should use far less space. Reduce its size without losing its content.
3. Prove that the space really came back by comparing with your number from Task 1.

**Evidence:** `ls -lh` of the folder after your changes, and the new used-space number (about 250 MB lower).

### Task 5: The deleted file that still uses space

Create the trap. This simulates an application that holds a log file open:

```bash
sudo fallocate -l 100M /var/log/demoapp/trap.log
tail -f /var/log/demoapp/trap.log > /dev/null &
```

Write down the PID printed by the shell, and record the used space in megabytes.

Now:

1. Delete `trap.log`.
2. Check the used space again. Did it drop?
3. Find out **why** it did not, and identify which process is responsible.
4. Release the space without rebooting.
5. Prove the space is back.

**Evidence:** used space before the delete, after the delete and after the fix; the output that reveals the responsible process.

### Task 6: Find out why the logs grew


### Task 7: Make sure it never happens again

Create a `logrotate` rule for `/var/log/demoapp/*.log` in `/etc/logrotate.d/demoapp` with these requirements:

- rotate every day
- keep 7 old copies
- compress rotated logs
- do not fail if a log is missing
- do not rotate empty logs

Then:

1. Test the rule with a dry run that changes nothing.
2. Force one real rotation and show the result. (Think: `debug.log` is empty after Task 4. What do you need to do first?)
3. Show that the system will run `logrotate` automatically every day.

**Evidence:** the rule file, the dry-run output, the folder listing after the forced rotation and the line that proves the daily schedule.

### Task 8: Clean up

Remove everything this lab created: the demo folder, the logrotate rule and the sample log. Check that no background job from Task 5 is left running.


---

## Hints

Try each task without looking first. If you are stuck, these are the tools to read about (use `man` or `--help`).

| Task | Tools to explore |
|---|---|
| 1 | `df` with the `--output` option |
| 2 | `du`, `sort`, `ls` |
| 3 | `find` with `-size` and `-exec` |
| 4 | `truncate`, `gzip` |
| 5 | `lsof` (look for a link count option), `kill`, `jobs` |
| 6 | `wc`, `grep`, `head`, `tail`, `cut` |
| 7 | `logrotate` options `-d` and `-f`, `systemctl list-timers` |
| 8 | `rm`, `jobs` |
| Bonus | `journalctl`, `du`, `df -i` |

---
## Questions

Answer each in 2 to 3 sentences.

1. What is the difference between `df` and `du`? When would you use each one?
3. Why is emptying a live log file safer than deleting it?

---
