# Lab: The Website Is Down

Troubleshooting a failed nginx service 
## Table of Contents

- [Overview](#overview)
- [Learning outcomes](#learning-outcomes)
- [Tools you will use](#tools-you-will-use)
- [Part 0: Build a healthy server](#part-0-build-a-healthy-server)
- [Part 1: Failure A, a configuration error](#part-1-failure-a-a-configuration-error)
- [Part 2: Failure B, the port is already in use](#part-2-failure-b-the-port-is-already-in-use)
- [Part 3: Clean up](#part-3-clean-up)
- [Your troubleshooting routine](#your-troubleshooting-routine)
- [Common problems](#common-problems)
- [What to submit](#what-to-submit)
- [Check your understanding](#check-your-understanding)
- [Challenge (optional)](#challenge-optional)

---

## Overview

**Story:** You are the on-call engineer. The company website suddenly stops working. In this lab you will first build a healthy web server, then break it in two different ways, and fix each failure using only logs and system tools, exactly like a real incident.

**Level:** Beginner

**What you will practise:** `systemctl`, `journalctl`, `nginx -t`, `ss`, `curl`, `kill`, editing a configuration file.

## Learning outcomes

After this lab you can:

1. Tell the difference between a service that is stopped, failed and running.
2. Read the service status and the journal to find the reason for a failure.
3. Validate an nginx configuration before restarting.
4. Find which process owns a network port and stop it.
5. Follow a repeatable troubleshooting order.

## Tools you will use

| Tool | What it answers |
|---|---|
| `curl -I localhost` | Does the website respond, and which server answered? |
| `systemctl status nginx` | Is the service running, failed or stopped? |
| `journalctl -u nginx` | Why did it fail? (the log messages) |
| `sudo nginx -t` | Is the configuration file valid? Which line is wrong? |
| `sudo ss -tulnp` | Which process is listening on which port? |
| `sudo kill PID` | Stop a process that is in the way |

---

## Part 0: Build a healthy server

### Step 0.1: Install nginx

```bash
sudo apt update
sudo apt install -y nginx
```

### Step 0.2: Start it now and at every boot

```bash
sudo systemctl enable --now nginx
```

### Step 0.3: Confirm the website works

```bash
curl -I localhost
```

Expected output (version numbers may differ):

```text
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Content-Type: text/html
```

`-I` asks for the response headers only. `200 OK` means success, and the `Server:` line tells you that nginx answered.

### Step 0.4: Back up the configuration

A backup lets you restore the server if you get stuck.

```bash
sudo cp -r /etc/nginx /root/nginx-backup
sudo ls /root/nginx-backup
```

You should see `nginx.conf`, `sites-available`, `sites-enabled` and other files.

**Checkpoint 0:** `curl -I localhost` shows `200 OK` and `systemctl status nginx` shows `active (running)` in green. Take a screenshot of both.

---

## Part 1: Failure A, a configuration error

### Step 1.1: Break the server

(In pair mode, your partner does this step.)

```bash
sudo sed -i '0,/worker_processes/s/worker_processes/worker_processes_BROKEN/' /etc/nginx/nginx.conf
sudo systemctl restart nginx
```

The restart fails with a message like this:

```text
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
```

The website is now down. Do **not** run the break command again and do not look at the file yet. Investigate like a real engineer.

### Step 1.2: Confirm the symptom

```bash
curl -I localhost
```

Expected output:

```text
curl: (7) Failed to connect to localhost port 80: Connection refused
```

Newer curl versions print `Failed to connect to localhost port 80 after 0 ms: Couldn't connect to server`. Both mean the same thing: nothing is accepting connections on port 80.

**What it tells you:** the problem is on the server, not in the browser or DNS.

### Step 1.3: Check the service status

```bash
systemctl status nginx
```

Look for these lines:

```text
Active: failed (Result: exit-code)
Process: 1234 ExecStartPre=/usr/sbin/nginx -t ... (code=exited, status=1/FAILURE)
```

**What it tells you:** the state is `failed`, not just `stopped`. The failing step is `ExecStartPre=/usr/sbin/nginx -t`, which is nginx testing its own configuration before starting. So the configuration is the suspect.

Press `q` to leave the status screen if it does not close.

### Step 1.4: Read the logs

```bash
journalctl -u nginx --no-pager -n 20
```

`-u nginx` shows only the nginx unit, `-n 20` shows the last 20 lines and `--no-pager` prints everything without scrolling mode.

Look for a line like this:

```text
nginx: [emerg] unknown directive "worker_processes_BROKEN" in /etc/nginx/nginx.conf:2
```

Write down: the file name, the line number and the word nginx does not understand.

### Step 1.5: Test the configuration

```bash
sudo nginx -t
```

Expected output:

```text
nginx: [emerg] unknown directive "worker_processes_BROKEN" in /etc/nginx/nginx.conf:2
nginx: configuration file /etc/nginx/nginx.conf test failed
```

**What it tells you:** the exact file and line to fix. Always run `nginx -t` before restarting nginx.

### Step 1.6: Fix the problem

Open the file and go to the line shown in the error:

```bash
sudo nano /etc/nginx/nginx.conf
```

Change `worker_processes_BROKEN` back to `worker_processes`. Save with `Ctrl+O`, press `Enter`, then exit with `Ctrl+X`.

If you prefer a one-line fix:

```bash
sudo sed -i 's/worker_processes_BROKEN/worker_processes/' /etc/nginx/nginx.conf
```

### Step 1.7: Validate, restart and verify

```bash
sudo nginx -t
```

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

```bash
sudo systemctl restart nginx
systemctl status nginx
curl -I localhost
```

You should see `active (running)` and `HTTP/1.1 200 OK`.

**Checkpoint 1:** take screenshots of (a) the failed `systemctl status`, (b) the `journalctl` error line, (c) the failing and then successful `nginx -t`, and (d) the final `200 OK`.

**Stuck?** Restore the backup and continue:

```bash
sudo cp /root/nginx-backup/nginx.conf /etc/nginx/nginx.conf
sudo nginx -t && sudo systemctl restart nginx
```

---

## Part 2: Failure B, the port is already in use

### Step 2.1: Break the server

(In pair mode, your partner does this step.)

Stop nginx, start another program on port 80, then try to start nginx:

```bash
sudo systemctl stop nginx
sudo python3 -m http.server 80 > /dev/null 2>&1 &
sudo systemctl start nginx
```

The start fails with the same kind of message as before:

```text
Job for nginx.service failed because the control process exited with error code.
```

### Step 2.2: Look at the symptom

```bash
curl -I localhost
```

This time something answers, but look carefully at the `Server:` line:

```text
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.10.12
```

**What it tells you:** a response does not mean nginx is working. Here, Python answered, not nginx. Never trust only the `200`, always check which server replied.

### Step 2.3: Check the status and the logs

```bash
systemctl status nginx
journalctl -u nginx --no-pager -n 20
```

Look for:

```text
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
```

**What it tells you:** the configuration is fine (the earlier `nginx -t` test passed), but another process already owns port 80. Run `sudo nginx -t` to prove the configuration is still valid.

### Step 2.4: Find who owns port 80

```bash
sudo ss -tulnp | grep ':80 '
```

Expected output (PID will differ):

```text
tcp   LISTEN  0  5  0.0.0.0:80  0.0.0.0:*  users:(("python3",pid=2345,fd=3))
```

Read it from the right: the process is `python3` and the PID is `2345`. Write down your PID.

Another way to find the same information:

```bash
sudo lsof -i :80
```

### Step 2.5: Stop the process in the way

Replace 2345 with your own PID:

```bash
sudo kill 2345
```

Check that port 80 is free (this command should print nothing):

```bash
sudo ss -tulnp | grep ':80 '
```

If the process is still there, use `sudo kill -9 2345` as a last resort.

### Step 2.6: Start nginx and verify

```bash
sudo systemctl start nginx
systemctl status nginx
curl -I localhost
```

Now the `Server:` line must say `nginx`:

```text
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
```

**Checkpoint 2:** take screenshots of (a) the `Address already in use` log line, (b) the `ss` output with the PID, (c) the kill command and the empty `ss` result, and (d) the final `200 OK` with `Server: nginx`.

---

## Part 3: Clean up

Make sure nothing is left from the exercises:

```bash
jobs
sudo ss -tulnp | grep ':80 '
sudo cp /root/nginx-backup/nginx.conf /etc/nginx/nginx.conf
sudo nginx -t && sudo systemctl restart nginx
curl -I localhost
```

The port check should show only `nginx`, and `curl` should return `200 OK`.

---

## Your troubleshooting routine

Use the same order every time a service will not start:

| Step | Command | What to look for |
|---|---|---|
| 1. Reproduce | `curl -I localhost` | Refused, timeout or the wrong `Server:` header |
| 2. State | `systemctl status nginx` | `failed`, `inactive` or `active`, and which step failed |
| 3. Logs | `journalctl -u nginx -n 20 --no-pager` | The `[emerg]` or `error` line |
| 4. Config | `sudo nginx -t` | File name and line number of the mistake |
| 5. Ports | `sudo ss -tulnp` | Who owns the port you need |
| 6. Fix | edit the file, or `kill` the other process | Change one thing at a time |
| 7. Verify | `nginx -t`, `restart`, `status`, `curl -I` | `active (running)` and `200 OK` from nginx |

## Check your understanding

1. In Part 1, how did you know the problem was the configuration and not the network?
2. In Part 2, `curl` returned `200 OK` while nginx was failed. How is that possible, and which header proved it?
3. What is the difference between `systemctl status` (the state) and `journalctl -u nginx` (the logs)?
4. Why should you run `sudo nginx -t` before every restart?
5. Write the troubleshooting order you would follow next time without looking at this lab.

