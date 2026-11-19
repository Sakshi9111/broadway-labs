# Lab: Enable HTTPS on nginx with a Self-Signed SSL Certificate

Secure the `todo.local` website with SSL/TLS · Broadway Infosys · DevOps Training · Linux for DevOps Engineers

## Table of Contents

- [Overview](#overview)
- [Learning outcomes](#learning-outcomes)
- [How HTTPS works (quick theory)](#how-https-works-quick-theory)
- [Part 0: Install and check nginx](#part-0-install-and-check-nginx)
- [Part 1: Create the self-signed certificate](#part-1-create-the-self-signed-certificate)
- [Part 2: Protect the key and verify the certificate](#part-2-protect-the-key-and-verify-the-certificate)
- [Part 3: Create the website](#part-3-create-the-website)
- [Part 4: Configure nginx for HTTPS](#part-4-configure-nginx-for-https)
- [Part 5: Enable the site and reload nginx](#part-5-enable-the-site-and-reload-nginx)
- [Part 6: Make the name todo.local work](#part-6-make-the-name-todolocal-work)
- [Part 7: Test from the terminal](#part-7-test-from-the-terminal)
- [Part 8: Trust the certificate and test in a browser](#part-8-trust-the-certificate-and-test-in-a-browser)
- [Part 9: Clean up](#part-9-clean-up)
- [Troubleshooting](#troubleshooting)
- [What to submit](#what-to-submit)
- [Check your understanding](#check-your-understanding)
- [Challenge (optional)](#challenge-optional)

---

## Overview

**Story:** The team has a small todo web application. Today it is served over plain HTTP, so passwords and data travel unencrypted. Your job is to enable HTTPS with an SSL/TLS certificate, redirect all HTTP traffic to HTTPS, and prove that it works.

**Time:** 60 to 75 minutes · **Level:** Beginner to intermediate

**What you will practise:** `openssl`, file permissions, nginx server blocks, `nginx -t`, `systemctl`, `/etc/hosts`, `curl`, `ss`.

**What you need**

- Ubuntu (VM, EC2 instance or WSL2 with systemd) and a user with `sudo`
- Internet access (to install nginx)
- For Part 8 on **WSL2**: a Windows browser (Chrome or Edge) and PowerShell opened **as Administrator**

**Why self-signed?** Public certificates (for example from Let's Encrypt) need a real public domain name. `todo.local` is a private test name, so we sign the certificate ourselves. The encryption is the same, but browsers do not trust it until we tell them to (Part 8).

## Learning outcomes

After this lab you can:

1. Generate a private key and a self-signed certificate with `openssl`.
2. Explain why the private key must be protected (`600`) and the certificate can be public (`644`).
3. Write an nginx configuration that listens on port 443 with SSL.
4. Redirect HTTP (port 80) to HTTPS with a `301` response.
5. Test HTTPS with `curl` and `openssl`, and trust a certificate in a browser.

## How HTTPS works (quick theory)

| Item | What it is |
|---|---|
| Private key (`.key`) | A secret file that stays on the server. Never share it. |
| Certificate (`.crt`) | A public file that contains the public key, the site name and the validity dates. The server sends it to every visitor. |
| Self-signed | The certificate is signed by itself, not by a trusted authority (CA). |
| SAN (Subject Alternative Name) | The list of names the certificate is valid for. Modern browsers **require** the site name here and ignore the CN. |
| Port 443 | The standard HTTPS port (HTTP uses 80). |

What happens when you open `https://todo.local`:

1. The browser connects to port 443.
2. nginx sends its certificate.
3. The browser checks the name, the dates and whether it trusts the signer.
4. If everything is fine, both sides create an encrypted session and the page loads.

A self-signed certificate fails step 3 (the signer is unknown) until you add it to the trusted list.

---

## Part 0: Install and check nginx

### Step 0.1: Install nginx

```bash
sudo apt update
sudo apt-get install -y nginx
```

### Step 0.2: Start it now and at every boot

```bash
sudo systemctl enable --now nginx
sudo systemctl status nginx
```

You should see `active (running)`. Press `q` to leave the status screen.

If the status shows `inactive` or `failed`, start it and check again:

```bash
sudo systemctl start nginx
sudo systemctl status nginx
```

### Step 0.3: Confirm it responds

```bash
curl -I localhost
```

```text
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
```

**Checkpoint 0:** screenshot of `systemctl status nginx` and the `200 OK` response.

---

## Part 1: Create the self-signed certificate

### Step 1.1: Create a folder for the certificate files

```bash
sudo mkdir -p /etc/nginx/ssl
```

`-p` means: do not fail if the folder already exists.

### Step 1.2: Generate the key and the certificate in one command

```bash
sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /etc/nginx/ssl/todo.local.key \
  -out /etc/nginx/ssl/todo.local.crt \
  -subj "/CN=todo.local" \
  -addext "subjectAltName=DNS:todo.local,DNS:www.todo.local"
```

The `\` at the end of a line means "the command continues on the next line". You can also type everything on one line.

What each option does:

| Option | Meaning |
|---|---|
| `req` | Work with certificate requests |
| `-x509` | Produce a finished self-signed certificate instead of a request for a CA |
| `-nodes` | "No DES": do not protect the key with a passphrase, so nginx can start without asking for one |
| `-newkey rsa:2048` | Create a new 2048-bit RSA private key |
| `-days 365` | The certificate is valid for one year |
| `-keyout` | Where to save the private key |
| `-out` | Where to save the certificate |
| `-subj "/CN=todo.local"` | The subject (Common Name) so openssl does not ask questions |
| `-addext "subjectAltName=..."` | The names the certificate is valid for (SAN). Browsers need this |

You will see output like this (the dots are progress):

```text
.......+++++
........+++++
```

### Step 1.2b: Confirm the two files exist

```bash
sudo ls -l /etc/nginx/ssl
```

```text
-rw------- 1 root root 1704 ... todo.local.key
-rw-r--r-- 1 root root 1119 ... todo.local.crt
```

**Checkpoint 1:** screenshot of the `openssl` command and the `ls -l` output.

---

## Part 2: Protect the key and verify the certificate

### Step 2.1: Set the correct permissions

```bash
sudo chmod 600 /etc/nginx/ssl/todo.local.key
sudo chmod 644 /etc/nginx/ssl/todo.local.crt
```

| File | Mode | Why |
|---|---|---|
| `todo.local.key` | `600` (owner read and write only) | Anyone who gets the private key can impersonate your site |
| `todo.local.crt` | `644` (everyone can read) | The certificate is public, every visitor receives it anyway |

### Step 2.2: Read the certificate details

```bash
sudo openssl x509 -in /etc/nginx/ssl/todo.local.crt -noout -subject -dates -ext subjectAltName
```

Expected output (dates will differ):

```text
subject=CN = todo.local
notBefore=Nov 18 08:00:00 2026 GMT
notAfter=Nov 18 08:00:00 2027 GMT
X509v3 Subject Alternative Name:
    DNS:todo.local, DNS:www.todo.local
```

Check these three things: the subject name, the one-year validity and both names in the SAN list.

**Checkpoint 2:** screenshot of the permissions (`ls -l`) and the certificate details.

---

## Part 3: Create the website

```bash
sudo mkdir -p /var/www/todo
echo "<h1>Todo app over HTTPS</h1>" | sudo tee /var/www/todo/index.html
```

Check the file:

```bash
cat /var/www/todo/index.html
```

```text
<h1>Todo app over HTTPS</h1>
```

---

## Part 4: Configure nginx for HTTPS

### Step 4.1: Create the site configuration

```bash
sudo tee /etc/nginx/sites-available/todo.local > /dev/null <<'EOF'
server {
    listen 80;
    server_name todo.local;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name todo.local;

    ssl_certificate     /etc/nginx/ssl/todo.local.crt;
    ssl_certificate_key /etc/nginx/ssl/todo.local.key;

    root /var/www/todo;
    index index.html;
}
EOF
```

Important: the `'EOF'` (with quotes) stops the shell from replacing `$host` and `$request_uri`. nginx must receive them unchanged.

### Step 4.2: Understand every line

**First server block: port 80 (HTTP)**

| Line | Meaning |
|---|---|
| `listen 80;` | Accept plain HTTP connections |
| `server_name todo.local;` | Use this block when the requested name is `todo.local` |
| `return 301 https://$host$request_uri;` | Send a permanent redirect to the same name and path over HTTPS |

**Second server block: port 443 (HTTPS)**

| Line | Meaning |
|---|---|
| `listen 443 ssl;` | Accept HTTPS connections |
| `ssl_certificate` | The public certificate sent to visitors |
| `ssl_certificate_key` | The private key (stays on the server) |
| `root /var/www/todo;` | Folder that contains the website files |
| `index index.html;` | The default file to serve |

**Checkpoint 4:** screenshot of `cat /etc/nginx/sites-available/todo.local`.

---

## Part 5: Enable the site and reload nginx

### Step 5.1: Enable the site with a symbolic link

```bash
sudo ln -s /etc/nginx/sites-available/todo.local /etc/nginx/sites-enabled/
ls -l /etc/nginx/sites-enabled/
```

nginx only reads sites that are linked in `sites-enabled`. `sites-available` is the storage place for all site files.

If you see `File exists`, the link is already there and you can continue.

### Step 5.2: Test the configuration, then reload

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Expected output:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

`&&` means: run the second command only if the first one succeeded. `reload` applies the new configuration without dropping existing connections.

If `nginx -t` shows an error, read the file name and line number in the message, fix that line and test again. Never reload a configuration that failed the test.

**Checkpoint 5:** screenshot of the successful `nginx -t` and `ls -l /etc/nginx/sites-enabled/`.

---

## Part 6: Make the name todo.local work

The name `todo.local` does not exist in DNS. We map it to our own machine in the hosts file.

### Step 6.1: Add the name inside Ubuntu

```bash
echo "127.0.0.1 todo.local" | sudo tee -a /etc/hosts
```

`-a` appends to the file instead of replacing it. Check it:

```bash
grep todo.local /etc/hosts
getent hosts todo.local
```

```text
127.0.0.1 todo.local
127.0.0.1       todo.local
```

**WSL users:** WSL may regenerate `/etc/hosts` when it restarts. If `todo.local` stops working later, add the line again.

---

## Part 7: Test from the terminal

### Step 7.1: Check that nginx listens on port 443

```bash
sudo ss -tulpn | grep :443
```

Expected output (PID will differ):

```text
tcp   LISTEN  0  511  0.0.0.0:443  0.0.0.0:*  users:(("nginx",pid=1234,fd=6),...)
```

`-t` TCP, `-u` UDP, `-l` listening, `-p` process, `-n` numbers. You should see `nginx` on port `443`.

### Step 7.2: Test the HTTP to HTTPS redirect

```bash
curl -I http://todo.local
```

```text
HTTP/1.1 301 Moved Permanently
Server: nginx/1.18.0 (Ubuntu)
Location: https://todo.local/
```

`301` plus a `Location` header starting with `https://` proves the redirect works.

### Step 7.3: Test HTTPS the plain way (it will fail)

```bash
curl https://todo.local
```

Expected output:

```text
curl: (60) SSL certificate problem: self-signed certificate
```

This is **correct and good**: curl refuses to trust a certificate signed by an unknown signer. The encryption works, but there is no trust yet.

### Step 7.4: Test HTTPS while skipping the trust check

```bash
curl -k https://todo.local
```

```text
<h1>Todo app over HTTPS</h1>
```

`-k` means "insecure": do not verify the certificate. Use it only for testing.

### Step 7.5: Test HTTPS properly by trusting our certificate

```bash
curl --cacert /etc/nginx/ssl/todo.local.crt https://todo.local
```

```text
<h1>Todo app over HTTPS</h1>
```

This tells curl: "trust this one certificate". It works because the certificate name matches `todo.local`.

### Step 7.6: Look at the certificate the server sends

```bash
openssl s_client -connect todo.local:443 -servername todo.local </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer
```

```text
subject=CN = todo.local
issuer=CN = todo.local
```

The subject and issuer are the same name. That is what **self-signed** means.

### Step 7.7: Optional, make the whole system trust the certificate (plain Linux)

```bash
sudo cp /etc/nginx/ssl/todo.local.crt /usr/local/share/ca-certificates/todo.local.crt
sudo update-ca-certificates
curl https://todo.local
```

Now `curl` works without `-k` because Ubuntu trusts the certificate. (Browsers like Firefox keep their own trust list.)

**Checkpoint 7:** screenshots of the `ss` result, the `301` redirect, the failing `curl`, and `curl -k` or `curl --cacert` returning the page.

---

## Part 8: Trust the certificate and test in a browser

This part is for **WSL2 users** whose browser runs on Windows. Plain Linux desktop users can skip to Part 9.

### Step 8.1: Copy the certificate to Windows

Run this in Ubuntu (WSL):

```bash
cp /etc/nginx/ssl/todo.local.crt /mnt/c/Users/Public/
ls -l /mnt/c/Users/Public/todo.local.crt
```

Only the **certificate** is copied. Never copy the private key.

### Step 8.2: Add the certificate to the Windows trusted list

Open **PowerShell as Administrator** (right-click, Run as administrator) and run:

```powershell
certutil -addstore -f "Root" C:\Users\Public\todo.local.crt
```

Expected output:

```text
Root "Trusted Root Certification Authorities"
Signature matches Public Key
Certificate "todo.local" added to store.
CertUtil: -addstore command completed successfully.
```

Make sure the quotes are straight and balanced: `"Root"` has a quote on each side and the file path has none.

### Step 8.3: Make Windows resolve todo.local

Still in PowerShell (Administrator):

```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 todo.local"
```

### Step 8.4: Open the site

1. Close all Chrome or Edge windows completely and reopen the browser.
2. Visit `https://todo.local`.
3. You should see **Todo app over HTTPS** and a padlock with no warning.
4. Visit `http://todo.local` and confirm it jumps to `https://todo.local`.
5. Click the padlock, open the certificate details and check the name and dates.

**Firefox note:** Firefox uses its own trust list. Import the certificate under Settings, Privacy and Security, Certificates, View Certificates, Authorities, Import. Or set `security.enterprise_roots.enabled` to `true` in `about:config`.

**Checkpoint 8:** screenshots of the `certutil` success message and the browser showing the padlock and the page.

---

## Part 9: Clean up

Remove what this lab created so nothing insecure stays on your machine.

### In Ubuntu

```bash
sudo rm /etc/nginx/sites-enabled/todo.local
sudo rm /etc/nginx/sites-available/todo.local
sudo rm -r /etc/nginx/ssl
sudo rm -r /var/www/todo
sudo sed -i '/todo.local/d' /etc/hosts
sudo rm -f /usr/local/share/ca-certificates/todo.local.crt
sudo update-ca-certificates --fresh
rm /mnt/c/Users/Public/todo.local.crt
sudo nginx -t && sudo systemctl reload nginx
```

(The `rm` of the Windows copy only applies to WSL users.)

### In Windows PowerShell (Administrator), WSL users only

```powershell
certutil -delstore "Root" todo.local
(Get-Content C:\Windows\System32\drivers\etc\hosts) | Where-Object { $_ -notmatch "todo.local" } | Set-Content C:\Windows\System32\drivers\etc\hosts
```

**Why clean up?** The private key for a certificate you trusted is stored on your machine. Anyone who obtained that key could impersonate `todo.local` to you. Remove trust when the lab is finished.

---

## Troubleshooting

| Problem | Reason and fix |
|---|---|
| `nginx -t` says `cannot load certificate` | The path in `ssl_certificate` is wrong or the file does not exist. Check with `sudo ls -l /etc/nginx/ssl`. |
| `nginx -t` says `no "ssl_certificate" is defined` | The line is missing in the 443 server block. Add both `ssl_certificate` lines. |
| `nginx -t` says `unknown directive` or `unexpected` | A typo or missing `;`. The error shows the exact line number. |
| `curl: (60) SSL certificate problem` | Expected for self-signed certificates. Use `-k` or `--cacert`, or trust the certificate. |
| `curl: (7) Connection refused` on 443 | nginx is not listening. Check `systemctl status nginx` and `sudo ss -tulpn \| grep :443`. |
| `curl: Could not resolve host: todo.local` | The hosts entry is missing. Redo Part 6 (and Step 8.3 for Windows). |
| Browser shows `ERR_CERT_AUTHORITY_INVALID` | The certificate is not trusted yet. Redo Step 8.2 and restart the browser completely. |
| Browser shows `ERR_CERT_COMMON_NAME_INVALID` | The certificate has no SAN for the name you typed. Recreate it with the `-addext` option. |
| Browser cannot open `todo.local` at all | Windows does not know the name. Check `C:\Windows\System32\drivers\etc\hosts` (Step 8.3). |
| Firefox still warns | Firefox uses its own trust list. Follow the Firefox note in Part 8. |
| `ln: failed to create symbolic link ... File exists` | The link already exists. This is fine. |
| `certutil` says the file cannot be found | Check the path and that the quotes are straight and balanced. |
| Port 443 already in use | Find the owner with `sudo ss -tulpn \| grep :443`, stop that service and reload nginx. |
| `Permission denied` | You forgot `sudo`. |

---

## What to submit

Submit one document with screenshots or pasted terminal output, in this order:

1. Checkpoint 0: nginx running
2. Checkpoint 1 and 2: key and certificate files, permissions and certificate details
3. Checkpoint 4 and 5: the configuration file, `nginx -t` success and the enabled link
4. Checkpoint 7: `ss`, the `301` redirect, the failing `curl`, and the working `curl -k` or `--cacert`
5. Checkpoint 8: the browser padlock and the page (WSL users)
6. Your answers to the questions below (2 to 3 sentences each)

## Check your understanding

1. What is the difference between the private key and the certificate? Which one may be shared?
2. Why is the key `chmod 600` but the certificate `chmod 644`?
3. What does `-x509` do, and what would happen without it?
4. Why must the certificate contain a SAN entry for `todo.local`?
5. What does `return 301 https://$host$request_uri;` do, and why use `301`?
6. Why did `curl https://todo.local` fail but `curl -k https://todo.local` succeed? Is the traffic encrypted in both cases?
7. In `curl --cacert`, what exactly are you telling curl?
8. Why should a self-signed certificate not be used for a public production website? What would you use instead?
9. Why do we run `sudo nginx -t` before `reload`?
10. Why remove the certificate from the Windows trust store after the lab?

## Challenge (optional)

1. Make `www.todo.local` work too: add it to `server_name` in both blocks, add it to your hosts files and test it. The certificate already contains it in the SAN.
2. Allow only modern TLS versions by adding this line inside the 443 server block, then test and reload:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

3. Use `openssl s_client -connect todo.local:443 -tls1_1 </dev/null` and explain why the connection fails after your change.
4. Create a second certificate named `api.local` and serve a different page on it.