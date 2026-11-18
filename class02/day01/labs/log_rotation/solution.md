# Solution: The Disk Is Filling Up

Linux for DevOps Engineers · Broadway Infosys · DevOps Training

> This file contains the **step-by-step solution** to `lab-disk-is-filling-up-problem.md`. Attempt the problem on your own first. Your numbers and exact output will differ slightly from the examples here.

## Table of Contents

- [Before you start](#before-you-start)
- [Task 1: Measure the starting point](#task-1-measure-the-starting-point)
- [Task 2: Find the biggest directory](#task-2-find-the-biggest-directory)
- [Task 3: Find the large files](#task-3-find-the-large-files)
- [Task 4: Free space safely](#task-4-free-space-safely)
- [Task 5: The deleted file that still uses space](#task-5-the-deleted-file-that-still-uses-space)
- [Task 6: Find out why the logs grew](#task-6-find-out-why-the-logs-grew)
- [Task 7: Make sure it never happens again](#task-7-make-sure-it-never-happens-again)
- [Task 8: Clean up](#task-8-clean-up)
---

## Before you start

Complete the **Setup** section of the problem file first. Check it with:

```bash
ls -lh /var/log/demoapp
wc -l /tmp/app.log
```

```text
-rw-r--r-- 1 root root 200M ... debug.log
-rw-r--r-- 1 root root  50M ... old.log
300 /tmp/app.log
```

---

## Task 1: Measure the starting point

```bash
df -h
df -h /
df -m --output=used /
```

Example output:

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        29G  8.4G   20G  30% /

  Used
  8602
```

**Write down the last number** (here 8602 MB). `-m` prints megabytes and `--output=used` prints only the used column.

How to read `df -h`:

| Column | Meaning |
|---|---|
| Size | Total size of the filesystem |
| Used | Space already used |
| Avail | Space still free |
| Use% | Percentage used (alerts usually fire above 80% or 90%) |
| Mounted on | Where the filesystem is attached |

**Why:** `df` tells you that a problem exists, but not what causes it.

---

## Task 2: Find the biggest directory

```bash
sudo du -sh /var/log/* | sort -h
```

The biggest item appears at the bottom:

```text
4.0K    /var/log/alternatives.log
...
12M     /var/log/journal
251M    /var/log/demoapp
```

Look inside the biggest directory:

```bash
sudo du -sh /var/log/demoapp/* | sort -h
ls -lh /var/log/demoapp
```

```text
50M     /var/log/demoapp/old.log
200M    /var/log/demoapp/debug.log
```

**Why this works:** `du -sh` prints one summarised, human-readable size per item. `sort -h` orders `4.0K`, `12M`, `1.2G` correctly. `sudo` is needed because some log folders are private. The method is always: start at the top, find the biggest folder, then repeat inside it.

---

## Task 3: Find the large files

Files larger than 100 MB:

```bash
sudo find /var/log -type f -size +100M
```

```text
/var/log/demoapp/debug.log
```

Files larger than 50 MB, with details:

```bash
sudo find /var/log -type f -size +50M -exec ls -lh {} \;
```

Only `debug.log` (200M) is listed. `old.log` is exactly 50 MB and `+50M` means *strictly more than* 50 MB, so it is not included. To include files of 50 MB and above, use `-size +49M`.

Useful size filters:

| Filter | Meaning |
|---|---|
| `-size +100M` | bigger than 100 MB |
| `-size +1G` | bigger than 1 GB |
| `-mtime +30` | not modified for more than 30 days |

---

## Task 4: Free space safely

### Why not rm?

`debug.log` is the live log of a running application. If you delete it, the application may keep writing to a nameless file and the space is **not** returned (Task 5 proves this). The safe way is to **empty** the file but keep it.

### 4.1 Empty debug.log

```bash
sudo truncate -s 0 /var/log/demoapp/debug.log
ls -lh /var/log/demoapp/debug.log
```

```text
-rw-r--r-- 1 root root 0 ... /var/log/demoapp/debug.log
```

### 4.2 Compress old.log

```bash
sudo gzip /var/log/demoapp/old.log
ls -lh /var/log/demoapp
```

`old.log` becomes `old.log.gz` and shrinks to a few hundred KB. This lab file is full of zeros so it compresses extremely well. Real logs usually shrink to about 10 to 20 percent.

### 4.3 Prove the space came back

```bash
df -m --output=used /
```

The number is now about **250 MB lower** than in Task 1 (for example 8602 down to about 8352).

---

## Task 5: The deleted file that still uses space

### 5.1 Create the trap

```bash
sudo fallocate -l 100M /var/log/demoapp/trap.log
tail -f /var/log/demoapp/trap.log > /dev/null &
```

The shell prints something like `[1] 4567`. **4567 is the PID.** Record the used space:

```bash
df -m --output=used /
```

### 5.2 Delete the file and check again

```bash
sudo rm /var/log/demoapp/trap.log
ls /var/log/demoapp
df -m --output=used /
```

The file is gone from the folder, **but the used space did not drop**.

### 5.3 Find the responsible process

```bash
sudo apt install -y lsof      # only if lsof is missing
sudo lsof +L1
```

Look for the word `(deleted)`:

```text
COMMAND  PID  USER  FD  TYPE DEVICE  SIZE/OFF NLINK  NODE NAME
tail    4567  you   3r  REG    8,1  104857600     0  1234 /var/log/demoapp/trap.log (deleted)
```

**Explanation:** `+L1` lists open files with a link count below 1, which means files that were deleted. `NLINK 0` means the file no longer has a name, but process `tail` (PID 4567) still holds it open, so Linux cannot release the space until that process closes it.

### 5.4 Release the space

```bash
kill 4567          # or: kill %1
df -m --output=used /
```

The used space drops by about 100 MB.

**Real-world fix:** restart the service that holds the file (`sudo systemctl restart myapp`), or empty the file with `truncate` **before** anyone deletes it.

---

## Task 6: Find out why the logs grew

| Question | Command | Answer |
|---|---|---|
| Number of lines | `wc -l /tmp/app.log` | `300` |
| Number of `ERROR` lines | `grep -c ERROR /tmp/app.log` | `42` |
| Last 5 errors | `grep ERROR /tmp/app.log \| tail -5` | the lines for orders 266, 273, 280, 287, 294 |
| First 3 order numbers | `grep ERROR /tmp/app.log \| cut -d= -f2 \| head -3` | `7`, `14`, `21` |

Example output of the last command:

```text
7
14
21
```

How the last command works: `grep ERROR` keeps only error lines, `cut -d= -f2` splits each line at `=` and keeps the second part (the order number), and `head -3` keeps the first three.

Useful `grep` options:

| Command | Meaning |
|---|---|
| `grep -c TEXT file` | count matching lines |
| `grep -i TEXT file` | ignore upper and lower case |
| `grep -v TEXT file` | show lines that do **not** match |
| `grep -n TEXT file` | show line numbers |
| `tail -f file` | follow a log live |

**What it tells you:** every 7th request fails with a payment error. In a real incident you would send this finding to the developers, because freeing the disk without fixing the cause means the log will fill up again.

---

## Task 7: Make sure it never happens again

### 7.1 Create the rule

```bash
sudo tee /etc/logrotate.d/demoapp > /dev/null <<'EOF'
/var/log/demoapp/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
EOF
```

| Line | Meaning |
|---|---|
| `/var/log/demoapp/*.log` | Which files this rule applies to |
| `daily` | Rotate once a day |
| `rotate 7` | Keep 7 old copies, delete older ones |
| `compress` | Compress rotated files with gzip |
| `missingok` | Do not fail if a log file is missing |
| `notifempty` | Skip files that are empty |

### 7.2 Dry run

```bash
sudo logrotate -d /etc/logrotate.d/demoapp
```

`-d` means debug: it prints what *would* happen and changes nothing. You will see lines like `considering log /var/log/demoapp/debug.log`. For a daily rule it may say a log does not need rotating yet. That is normal.

### 7.3 Force one real rotation

`debug.log` is empty after Task 4, and `notifempty` would skip it. Add one line first:

```bash
echo "test entry" | sudo tee -a /var/log/demoapp/debug.log
sudo logrotate -f /etc/logrotate.d/demoapp
ls -lh /var/log/demoapp
```

```text
-rw-r--r-- 1 root root   0 ... debug.log
-rw-r--r-- 1 root root  ... ... debug.log.1.gz
-rw-r--r-- 1 root root  ... ... old.log.gz
```

The old content moved to `debug.log.1.gz` and a fresh empty `debug.log` was created.

### 7.4 Prove it runs daily

```bash
systemctl list-timers | grep logrotate
```

You should see `logrotate.timer`. systemd runs logrotate every day, so nobody has to remember to do it.

---

## Task 8: Clean up

```bash
jobs
sudo rm -rf /var/log/demoapp
sudo rm -f /etc/logrotate.d/demoapp /tmp/app.log
df -h /
```

If `jobs` shows a leftover background job, stop it with `kill %1` and run `jobs` again.

---

