# Lab: Host a Node.js App Behind Nginx

**Course:** DevOps Training, Broadway Infosys
**Level:** Beginner friendly (every step is explained)
**Time:** about 90 minutes (Parts 1 to 6 are the core, Parts 7 to 10 are extra)

---

## What you will build

```
 Browser  ───►  Nginx (port 80)  ───►  Node.js app (port 3000)
                  │                        │
                  ▼                        ▼
         /var/log/nginx/*.log       PM2 logs (stdout/stderr)
```

Nginx is the **front door** that faces the internet. Your Node.js app sits **behind** it and is never exposed directly.

## What you will learn

- Install and check Nginx
- Create a small Node.js (Express) app and keep it running with PM2
- Connect Nginx to Node with `proxy_pass` (reverse proxy)
- Serve static files straight from Nginx
- Read Nginx logs and Node logs, and trace one request across both
- Load balance three copies of the app
- Add HTTPS
- Run the same setup with Docker and compare

## What you need

- An Ubuntu 22.04 or 24.04 server (an EC2 instance or a local VM) with `sudo` access
- Internet access from the server
- If you use EC2: open **port 80** (and 443 for Part 9) in the security group. **Do not open port 3000.** That is the point of the lab.

> **Tip:** Run every command exactly as shown. After each part there is a **Checkpoint**. Do not move on until the checkpoint passes.

---

## Part 0: Prepare the server

**Why:** a fresh package list avoids install errors.

```bash
sudo apt update
sudo apt install -y curl
```

---

## Part 1: Install Nginx and see the default page

**Why:** first confirm Nginx itself works before adding anything.

```bash
sudo apt install -y nginx
sudo systemctl status nginx
```

You should see `active (running)` in green. Press `q` to leave the status screen.

Test it:

```bash
curl -I http://localhost
```

Expected: the first line is `HTTP/1.1 200 OK` and there is a `Server: nginx` line.

Open `http://<your-server-ip>` in a browser. You should see **"Welcome to nginx!"**.

**Useful commands to remember**

| Command | What it does |
|---|---|
| `sudo systemctl start nginx` | start |
| `sudo systemctl stop nginx` | stop |
| `sudo systemctl reload nginx` | apply config changes without dropping connections |
| `sudo nginx -t` | test the config for mistakes |

**Checkpoint 1:** the browser shows "Welcome to nginx!"

---

## Part 2: Create the Node.js app

**Why:** this is the app Nginx will protect and serve.

### 2.1 Install Node.js

The Node version in Ubuntu's own repository is too old, so use NodeSource (Node 22 LTS):

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node -v
npm -v
```

`node -v` should print `v22.x.x`.

### 2.2 Create the project

```bash
mkdir -p ~/myapp && cd ~/myapp
npm init -y
npm install express morgan
```

- `express` is the web framework.
- `morgan` prints one log line for every request.

### 2.3 Write the app

```bash
nano app.js
```

Paste this:

```js
const express = require("express");
const morgan = require("morgan");

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || "127.0.0.1";

app.set("trust proxy", true);
app.use(morgan(":remote-addr :method :url :status :response-time ms"));

app.get("/", (req, res) => {
  console.log("home page visited");
  res.send(`Hello from Node! Served by process ${process.pid} on port ${PORT}`);
});

app.get("/whoami", (req, res) => {
  res.json({
    ip: req.ip,
    host: req.headers.host,
    proto: req.headers["x-forwarded-proto"] || "http",
  });
});

app.get("/fail", (req, res) => {
  console.error("payment failed");
  res.status(500).send("Something broke");
});

app.listen(PORT, HOST, () => {
  console.log(`App listening on ${HOST}:${PORT}`);
});
```

**Read the code**

| Line | Meaning |
|---|---|
| `PORT` / `HOST` | read from environment variables, with defaults `3000` and `127.0.0.1` |
| `127.0.0.1` | only the same machine can reach the app. Outsiders must come through Nginx |
| `trust proxy` | makes `req.ip` show the real user's IP when Nginx forwards it |
| `/fail` | a route that fails on purpose, for the logs exercise |

Save with `Ctrl+O`, `Enter`, then exit with `Ctrl+X`.

### 2.4 Run it and test

```bash
node app.js
```

You should see `App listening on 127.0.0.1:3000`. Leave it running and open a **second terminal**:

```bash
curl http://127.0.0.1:3000/
```

Expected: `Hello from Node! Served by process 1234 on port 3000` (the number will differ).

Look at the first terminal. You should see a log line similar to:

```
home page visited
127.0.0.1 GET / 200 3.215 ms
```

Press `Ctrl+C` in the first terminal to stop the app.

**Checkpoint 2:** curl returned the hello message and the log lines appeared.

---

## Part 3: Keep the app running with PM2

**Why:** `node app.js` stops when you close the terminal or the app crashes. PM2 keeps it alive and restarts it after a reboot.

```bash
sudo npm install -g pm2
cd ~/myapp
pm2 start app.js --name myapp
pm2 list
```

The status should be `online`.

Make it survive reboots:

```bash
pm2 save
pm2 startup
```

`pm2 startup` prints a command that starts with `sudo env PATH=...`. **Copy that whole line and run it.**

Test it again:

```bash
curl http://127.0.0.1:3000/
pm2 logs myapp --lines 10
```

**Try this:** run `pm2 stop myapp`, then curl again (it fails), then `pm2 start myapp`.

**Checkpoint 3:** `pm2 list` shows `myapp` as `online` and curl works.

---

## Part 4: Connect Nginx to Node (reverse proxy)

**Why:** now users reach Nginx on port 80, and Nginx passes the request to Node.

### 4.1 Create the site config

```bash
sudo nano /etc/nginx/sites-available/myapp
```

Paste:

```nginx
server {
  listen 80;
  server_name example.com;

  access_log /var/log/nginx/myapp.access.log;
  error_log  /var/log/nginx/myapp.error.log warn;

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
```

**Read the config**

| Line | Meaning |
|---|---|
| `listen 80;` | accept web traffic on port 80 |
| `server_name _;` | match any host name (fine for a lab) |
| `access_log` / `error_log` | where this site writes its logs |
| `location / {` | applies to every URL |
| `proxy_pass` | send the request to the Node app |
| `proxy_set_header ...` | tell Node the real IP, host and protocol, because Node only sees Nginx |

### 4.2 Enable it

```bash
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

- `ln -s` enables the site.
- The default site is removed so it does not answer instead of your app.
- `nginx -t` must say `syntax is ok` and `test is successful`. **Always run it before reload.**

### 4.3 Test

```bash
curl http://example.com
```

Open `http://<your-server-ip>/` in the browser. You should see the hello message from Node, not the Nginx welcome page.

### 4.4 Confirm Node is hidden

```bash
sudo ss -tlnp | grep -E ':80|:3000'
```

You should see Nginx on `0.0.0.0:80` and Node on **`127.0.0.1:3000`**. Port 3000 is local only. From your own laptop, `http://<server-ip>:3000` should **not** work.

**Checkpoint 4:** the browser shows the Node message through port 80.

---

## Part 5: Serve static files directly from Nginx

**Why:** Nginx is much faster than Node at sending files like images, CSS and JS. Node should not waste time on them.

```bash
sudo mkdir -p /var/www/myapp/static
echo "Hello from Nginx static" | sudo tee /var/www/myapp/static/hello.txt
```

Edit the config:

```bash
sudo nano /etc/nginx/sites-available/myapp
```

Add this block **above** `location / {`:

```nginx
  location /static/ {
    root /var/www/myapp;
  }
```

Nginx joins `root` + the URL, so `/static/hello.txt` becomes `/var/www/myapp/static/hello.txt`.

```bash
sudo nginx -t && sudo systemctl reload nginx
curl http://example.com/static/hello.txt
```

Expected: `Hello from Nginx static`.

Now check something important:

```bash
pm2 logs myapp --lines 5
```

There is **no new log line** for the static request. Nginx answered it by itself and Node never knew.

**Checkpoint 5:** the static file loads and Node's log did not change.

---

## Part 6: Read the logs

Two places write logs, so you need to know both.

| Who | What it logs | Where |
|---|---|---|
| Nginx access log | every request: IP, time, URL, status | `/var/log/nginx/myapp.access.log` |
| Nginx error log | Nginx problems (for example Node is down) | `/var/log/nginx/myapp.error.log` |
| Node app | `console.log`, `console.error`, morgan lines | `pm2 logs myapp` |

### 6.1 Generate traffic

```bash
curl http://example.com/
curl http://example.com/whoami
curl http://example.com/fail
```

### 6.2 Read the Nginx access log

```bash
sudo tail -n 5 /var/log/nginx/myapp.access.log
```

A line looks like this:

```
127.0.0.1 - - [23/Nov/2026:10:15:32 +0000] "GET /whoami HTTP/1.1" 200 85 "-" "curl/8.5.0"
```

Fields in order: client IP, time, request, status code, bytes sent, referrer, user agent. You should see `200`, `200` and `500`.

### 6.3 Read the Node log

```bash
pm2 logs myapp --lines 10
```

You will see the morgan lines and the `payment failed` message from `/fail`.

### 6.4 Cause a 502 on purpose

```bash
pm2 stop myapp
curl -i http://example.com/
sudo tail -n 3 /var/log/nginx/myapp.error.log
pm2 start myapp
```

Expected: `HTTP/1.1 502 Bad Gateway`, and the error log says `connect() failed (111: Connection refused) while connecting to upstream`. **Meaning: Nginx is fine, but Node is down.**

### 6.5 Count status codes (bonus)

```bash
sudo awk '{print $9}' /var/log/nginx/myapp.access.log | sort | uniq -c
```

**Checkpoint 6:** you saw 200 and 500 in the access log, and a 502 with "Connection refused" in the error log.

---

## Part 7 (Extra): Trace one request across both logs

**Why:** in real systems you must follow one user request from Nginx to Node. A shared **request ID** does this.

### 7.1 Nginx: define a log format with the ID

```bash
sudo nano /etc/nginx/conf.d/logformat.conf
```

```nginx
log_format traced '$remote_addr [$time_local] "$request" $status $request_time $request_id';
```

Edit the site file. Change the access log line and add one header inside `location / {`:

```nginx
  access_log /var/log/nginx/myapp.access.log traced;
```

```nginx
    proxy_set_header X-Request-ID $request_id;
```

### 7.2 Node: print the ID

In `~/myapp/app.js`, replace the `app.use(morgan(...))` line with:

```js
morgan.token("rid", (req) => req.headers["x-request-id"]);
app.use(morgan(":rid :remote-addr :method :url :status"));
```

### 7.3 Restart and test

```bash
sudo nginx -t && sudo systemctl reload nginx
pm2 restart myapp
curl http://example.com/
sudo tail -n 1 /var/log/nginx/myapp.access.log
pm2 logs myapp --lines 3c
```

The last field in the Nginx line (a long hex string) should match the first field in the Node line. Use `grep` with part of that ID to find both.

**Checkpoint 7:** the same ID appears in both logs.

---

## Part 8 (Extra): Load balancing

**Why:** run several copies of the app and let Nginx share the traffic.

### 8.1 Start three copies

```bash
cd ~/myapp
pm2 delete myapp
PORT=3000 pm2 start app.js --name myapp-3000
PORT=3001 pm2 start app.js --name myapp-3001
PORT=3002 pm2 start app.js --name myapp-3002
pm2 list
```

### 8.2 Add an upstream group

Put this at the **very top** of `/etc/nginx/sites-available/myapp`, above `server {`:

```nginx
upstream node_app {
  server 127.0.0.1:3000;
  server 127.0.0.1:3001;
  server 127.0.0.1:3002;
}
```

In `location / {`, change the `proxy_pass` line to:

```nginx
    proxy_pass http://node_app;
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### 8.3 Watch it balance

```bash
for i in 1 2 3 4 5 6; do curl -s http://localhost/; echo; done
```

You will see the **port number rotate** 3000, 3001, 3002 and the process numbers differ. This is round robin, the default.

### 8.4 Kill one and see it survive

```bash
pm2 stop myapp-3001
for i in 1 2 3 4 5 6; do curl -s http://localhost/; echo; done
```

Users still get answers from the other two. Check the error log to see Nginx noticed.

```bash
pm2 start myapp-3001
```

**Checkpoint 8:** responses rotate across three ports and still work with one stopped.

---

## Part 9 (Extra): Add HTTPS

**Why:** HTTPS encrypts traffic. Nginx handles it (called TLS termination) and talks plain HTTP to Node.

### Option A: self-signed certificate (no domain needed, for practice)

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/myapp.key \
  -out /etc/ssl/certs/myapp.crt \
  -subj "/CN=localhost"
```

Add a second server block at the bottom of `/etc/nginx/sites-available/myapp`:

```nginx
server {
  listen 443 ssl;
  server_name _;

  ssl_certificate     /etc/ssl/certs/myapp.crt;
  ssl_certificate_key /etc/ssl/private/myapp.key;
  ssl_protocols TLSv1.2 TLSv1.3;

  location / {
    proxy_pass http://node_app;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

If you skipped Part 8, use `proxy_pass http://127.0.0.1:3000;` instead.

```bash
sudo nginx -t && sudo systemctl reload nginx
curl -k https://localhost/whoami
```

`-k` tells curl to accept the self-signed certificate. The output should show `"proto":"https"`.

### Option B: real certificate (needs a domain pointing to your server)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
sudo certbot renew --dry-run
```

Set `server_name yourdomain.com;` first. Certbot edits the config, adds the redirect from 80 to 443 and renews automatically.

**Checkpoint 9:** `https://localhost/whoami` shows `"proto":"https"`.

---


---

## Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| Still see "Welcome to nginx!" | default site still enabled | `sudo rm /etc/nginx/sites-enabled/default`, then reload |
| `nginx -t` fails | typo or missing `;` | read the file name and line number in the message |
| 502 Bad Gateway | Node is down or wrong port | `pm2 list`, check `proxy_pass` port, read `error.log` |
| 504 Gateway Timeout | Node is too slow | check the app, raise `proxy_read_timeout` |
| 403 Forbidden on static file | wrong path or permissions | check the `root` path and `ls -l` on the file |
| 404 on `/static/hello.txt` | file is not under `root` + URL path | file must be at `/var/www/myapp/static/hello.txt` |
| Page does not open from browser | port 80 closed in firewall | open port 80 in the security group |
| `Address already in use` | another process owns the port | `sudo ss -tlnp \| grep :80` then stop it |
| Docker 502 | `proxy_pass` still `127.0.0.1`, or app on `127.0.0.1` | use `app:3000` and `HOST=0.0.0.0` |
| Config change not applied | forgot to reload | `sudo nginx -t && sudo systemctl reload nginx` |

---

## Cleanup

```bash
pm2 delete all && pm2 save
sudo rm -f /etc/nginx/sites-enabled/myapp /etc/nginx/conf.d/logformat.conf
sudo systemctl reload nginx
```

---

## Classwork

1. Run `curl` against `/`, `/whoami` and `/fail`. Find each request in the Nginx access log and in the Node log. Which status did `/fail` return?
2. Stop the app and request the site. Which status do you get, and what does `error.log` say?
3. Add `$request_id` to the log format and find one ID in both logs.
4. Remove a semicolon from the site config, run `nginx -t`, and fix the error from the message.
5. Run three app copies, stop one, and prove users are not affected.


---

## Command cheat sheet

```bash
sudo nginx -t                         # test config
sudo systemctl reload nginx           # apply config
sudo tail -f /var/log/nginx/myapp.access.log
sudo tail -f /var/log/nginx/myapp.error.log
pm2 list                              # app status
pm2 logs myapp                        # app logs
pm2 restart myapp                     # restart app
sudo ss -tlnp | grep -E ':80|:3000'   # who is listening
docker compose up -d --build         # start containers
docker compose logs -f               # container logs
```