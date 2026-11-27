# Node.js Todo App: Run It 3 Ways

A small todo app built with Node.js and Express. You will run the same app three ways:

1. **Directly** on your machine, on a port you choose
2. **In a container** with a `Dockerfile`
3. **With Docker Compose**

```
nodejs-todo/
├── src/server.js         the web server and API
├── src/store.js          saves todos to data/todos.json
├── public/index.html     the web page
├── test/                 unit tests
├── scripts/build.js      the build step (creates dist/)
├── package.json          scripts and dependencies
├── Dockerfile            how to build the image
└── docker-compose.yml    how to run the container
```

## What you need

| For | Check with | Needed version |
|---|---|---|
| Parts 1 | `node -v` and `npm -v` | Node.js 20 or newer |
| Parts 2 and 3 | `docker -v` and `docker compose version` | any recent Docker |

---

## Part 1: Run it directly on a port

### 1.1 Install the libraries

```bash
cd nodejs-todo
npm ci
```

`npm ci` reads `package-lock.json` and installs the exact libraries into a new `node_modules/` folder.

### 1.2 Start the app

```bash
node src/server.js
```

You should see:

```
Todo app listening on http://localhost:3000
```

Open **http://localhost:3000** in your browser, add a todo, tick it and delete it. The footer says `not built (running from src/ in dev mode)`.

Test the API from a second terminal:

```bash
curl http://localhost:3000/api/info
curl http://localhost:3000/api/todos
```

Stop the app with `Ctrl+C`.

### 1.3 Choose the port

The app reads the port from the `PORT` environment variable (default `3000`).

| System | Command |
|---|---|
| Linux, macOS, Git Bash | `PORT=4000 node src/server.js` |
| Windows PowerShell | `$env:PORT=4000; node src/server.js` |
| Windows cmd | `set PORT=4000 && node src/server.js` |

Open **http://localhost:4000**.

To accept connections only from your own machine, add `HOST=127.0.0.1` (the default `0.0.0.0` accepts connections from the network).

### 1.4 The proper way: test, build, start

```bash
npm test
npm run build
npm start
```

| Command | What it does |
|---|---|
| `npm test` | runs the 3 unit tests |
| `npm run build` | runs the tests first, then copies the app into `dist/` and writes `dist/build-info.json` |
| `npm start` | runs the built app from `dist/` |

Refresh the page. The footer now says `Build: v1.0.0 built <time>`.

> Todos are saved in `data/todos.json`. Stop and start the app and they are still there.

**Checkpoint 1:** the page opens on your chosen port. Stop the app before Part 2 so port 3000 is free.

---

## Extra: Where do all the libraries come from?

After `npm ci` you will see a `node_modules/` folder with about 65 folders, but `package.json` lists only **one** library (`express`). Where did the rest come from?

Each library you install has its own dependencies, and those have theirs. npm installs the whole chain. These extra packages are called **transitive dependencies**.

### Three things, three jobs

| | What it holds | In this project |
|---|---|---|
| `package.json` | what **you** asked for | 1 library: `express` |
| `package-lock.json` | the **full list** with the exact version of everything | express plus every package it needs |
| `node_modules/` | the **actual downloaded code** | the ~65 folders |

*Think of ordering a pizza.* The menu line says "pizza" (`package.json`). The pizza needs dough, sauce and cheese, and the dough needs flour and yeast. The receipt lists everything (`package-lock.json`), and the kitchen holds the ingredients (`node_modules/`).

### Where the folders came from (simplified)

npm puts them all in one flat `node_modules/` folder, so they look equal in `ls`. Your own code never asked for them. Express uses them inside, for example `qs` to read query strings and `mime-types` to set file types.

### How `npm ci` got them

1. It read `package-lock.json`. Every package there has an exact version, a download address and a checksum.
2. It downloaded each package from the npm registry (`https://registry.npmjs.org`).
3. It checked the checksum so nothing was changed on the way.
4. It unpacked each package into `node_modules/`.

See it in the lock file:

```bash
grep -A4 '"node_modules/ms"' package-lock.json
```

You will see the `version`, the `resolved` download URL and the `integrity` checksum.

### Try it yourself

```bash
ls node_modules | wc -l                  # how many packages were installed
npm ls                                   # only the libraries you asked for
npm ls --all                             # the full dependency tree
npm ls ms                                # who needs "ms"? (debug, which express needs)
npm explain ms                           # the same question, explained
cat node_modules/express/package.json    # look at its own "dependencies" list
```

### Things to remember

- **`^5.3.0`** in `"express": "^5.3.0"` means any 5.x version from 5.3.0 up. The lock file pins the exact version that was installed, so `npm ci` gives every student the same result.
- **One small dependency can pull in dozens of packages.** That is why teams watch what they install and keep libraries updated for security.
- **Never commit `node_modules/`.** It is rebuilt from the lock file, which is why `.gitignore` and `.dockerignore` list it. Docker runs `npm ci` itself.
- **Your own code is in `src/`**, not in `node_modules/`. Only downloaded libraries go in `node_modules/`.

### Exercise

1. Run `npm ls ms`. Which library needs `ms`, and which library needs that one?
2. Delete `node_modules/`, then run `npm ci` again. How long does it take?
3. Open `package-lock.json` and find the `integrity` line for `express`. What is it used for?

---

## Part 2: Run it with a Dockerfile

### 2.1 Read the Dockerfile

```dockerfile
# Stage 1: BUILD
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: RUN
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
RUN mkdir -p data && chown node:node data
USER node
EXPOSE 3000
CMD ["node", "dist/src/server.js"]
```

| Line | Meaning |
|---|---|
| `FROM node:22-alpine AS build` | start from a small Linux image that already has Node 22 |
| `WORKDIR /app` | work inside the `/app` folder |
| `COPY package*.json ./` then `RUN npm ci` | install libraries first, so Docker can **cache** this layer when only the code changes |
| `COPY . .` | copy the project files in |
| `RUN npm run build` | run the tests and create `dist/` (the build fails if a test fails) |
| second `FROM` | start a fresh, small image for running |
| `npm ci --omit=dev` | install only the libraries needed to run |
| `COPY --from=build` | take only `dist/` from the build stage |
| `USER node` | do not run as root |
| `EXPOSE 3000` | documents the port the app uses |
| `CMD [...]` | the command that starts the app |

### 2.2 Build the image

```bash
docker build -t nodejs-todo:1.0 .
docker images nodejs-todo
```

You will see the build steps run, including the tests.

### 2.3 Run a container

```bash
docker run -d --name todo -p 3000:3000 nodejs-todo:1.0
docker ps
```

Open **http://localhost:3000**. The footer shows the build stamp.

**Port mapping:** `-p 3000:3000` means `HOST_PORT:CONTAINER_PORT`. The app inside the container always uses 3000. To open it on host port 4000 instead:

```bash
docker rm -f todo
docker run -d --name todo -p 4000:3000 nodejs-todo:1.0
```

Now open **http://localhost:4000**.

### 2.4 Look inside

```bash
docker logs -f todo        # app output (Ctrl+C to leave)
docker exec -it todo sh    # open a shell inside (type exit to leave)
```

### 2.5 Keep the data

Todos live inside the container, so they disappear when the container is removed. Prove it, then fix it with a volume:

```bash
docker rm -f todo
docker run -d --name todo -p 3000:3000 nodejs-todo:1.0
# add a todo in the browser, then:
docker rm -f todo
docker run -d --name todo -p 3000:3000 nodejs-todo:1.0
# the todo is gone
```

```bash
docker rm -f todo
docker run -d --name todo -p 3000:3000 -v todo-data:/app/data nodejs-todo:1.0
# add a todo, remove the container, run the same command again: the todo is still there
```

`-v todo-data:/app/data` stores `/app/data` in a Docker **volume** named `todo-data` that outlives the container.

### 2.6 Clean up

```bash
docker rm -f todo
```


---

## Part 3: Run it with Docker Compose

Part 2 needed long commands. Compose keeps them in a file.

### 3.1 Read docker-compose.yml

```yaml
services:
  todo:
    build: .
    image: nodejs-todo:1.0
    container_name: nodejs-todo
    ports:
      - "${HOST_PORT:-3000}:3000"
    volumes:
      - todo-data:/app/data
    restart: unless-stopped

volumes:
  todo-data:
```

| Line | Same as in Part 2 |
|---|---|
| `build: .` | `docker build` using the Dockerfile in this folder |
| `ports` | `-p`. `${HOST_PORT:-3000}` uses the `HOST_PORT` variable, or 3000 if it is not set |
| `volumes` | `-v`. The volume is declared at the bottom |
| `restart: unless-stopped` | restart after a crash or a reboot |

### 3.2 Start it

Make sure the Part 2 container is gone (`docker rm -f todo`), then:

```bash
docker compose up -d --build
docker compose ps
```

Open **http://localhost:3000**.

Use another host port:

```bash
HOST_PORT=4000 docker compose up -d
```

(PowerShell: `$env:HOST_PORT=4000; docker compose up -d`)

### 3.3 Everyday commands

```bash
docker compose logs -f     # follow the logs
docker compose restart     # restart the app
docker compose stop        # stop, keep the container
docker compose start       # start it again
docker compose down        # remove the container (data volume stays)
docker compose down -v     # remove the container AND the saved todos
```

**Try this:** add a todo, run `docker compose down`, then `docker compose up -d`. The todo is still there because of the volume.

**Checkpoint 3:** `docker compose up -d --build` starts the app with one command.

---

## The three ways compared

| | Part 1: direct | Part 2: Dockerfile | Part 3: Compose |
|---|---|---|---|
| Needs Node installed | yes | no | no |
| Start command | `npm start` | `docker run ...` (long) | `docker compose up -d` |
| Change port | `PORT=4000` | `-p 4000:3000` | `HOST_PORT=4000` |
| Saved data | `data/` folder | needs `-v` | volume in the file |
| Restart after crash | no | add `--restart` | `restart:` in the file |
| Settings stored in | your head | your terminal history | `docker-compose.yml` |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Browser shows `ERR_ADDRESS_INVALID` | you opened `http://0.0.0.0:3000`. `0.0.0.0` is a listen address, not a place to browse to | open `http://localhost:3000` instead |
| `EADDRINUSE: address already in use` | something already uses that port | stop it or use another `PORT` |
| `port is already allocated` (Docker) | another container or app uses the host port | `docker ps`, stop it, or change the host port |
| `npm ci` fails with no lockfile | you are in the wrong folder | `cd nodejs-todo`, check `ls package-lock.json` |
| `permission denied` on the Docker socket | your user is not in the docker group | `sudo usermod -aG docker $USER`, then log out and in |
| Container exits at once | the app crashed | `docker logs todo` |
| Build fails at `npm run build` | a unit test failed | read the test output above the error |
| Page does not open from another computer | firewall or cloud security group | open the host port |
| Todos gone after the container is removed | no volume | add `-v todo-data:/app/data` |

## Clean everything

```bash
docker compose down -v
docker rm -f todo
docker volume rm todo-data
docker rmi nodejs-todo:1.0
```