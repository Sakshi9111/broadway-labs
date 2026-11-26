# Todo App (Spring Boot)

A simple Todo application built with Java and Spring Boot. It has a REST API, a database that keeps your data between restarts, and a small web page to manage todos.

Created as a class project for the DevOps Training course at Broadway Infosys.

## Features

- Add, view, update, complete and delete todos
- Layered structure: Controller, Service, Repository
- Data stored in an H2 database file, so todos survive restarts
- Input validation with clear JSON error messages
- Simple web page served by the same application
- Port configurable through an environment variable

## Tech stack

| Part | Technology |
|------|------------|
| Language | Java 17 |
| Framework | Spring Boot 3 (Spring Web, Spring Data JPA, Validation) |
| Database | H2 (file mode) |
| Build tool | Maven |
| Frontend | Plain HTML and JavaScript |

## Prerequisites

Check that these are installed:

```bash
java -version    # 17 or higher
mvn -v           # Apache Maven 3.x
```

## Getting started

1. Clone the repository and open the project folder:

   ```bash
   git clone <your-repo-url>
   cd todo
   ```

2. Run the application:

   ```bash
   mvn spring-boot:run
   ```

3. Wait for the message `Started TodoApplication`, then open the web page:

   <http://localhost:8080>

To stop the application, press `Ctrl + C`.

### Run on a different port

The port is read from the `PORT` environment variable and defaults to `8080`.

```bash
PORT=9090 mvn spring-boot:run
```

On Windows PowerShell:

```powershell
$env:PORT=9090; mvn spring-boot:run
```

### Build a runnable jar

```bash
mvn clean package -DskipTests
java -jar target/todo-0.0.1-SNAPSHOT.jar
```

## Project structure

```
todo/
|-- pom.xml
|-- src/main/
|   |-- java/com/example/todo/
|   |   |-- TodoApplication.java          # application entry point
|   |   |-- controller/
|   |   |   `-- TodoController.java       # REST endpoints
|   |   |-- service/
|   |   |   `-- TodoService.java          # business logic
|   |   |-- repository/
|   |   |   `-- TodoRepository.java       # database access
|   |   |-- model/
|   |   |   |-- Todo.java                 # database entity
|   |   |   `-- TodoRequest.java          # request body with validation
|   |   `-- exception/
|   |       |-- TodoNotFoundException.java
|   |       `-- GlobalExceptionHandler.java
|   `-- resources/
|       |-- application.properties        # configuration
|       `-- static/index.html             # web page
`-- data/                                 # H2 database files (created on first run)
```

## How it works

```
Browser / curl
      |
      v
 Controller   handles HTTP requests and responses
      |
      v
  Service     business logic
      |
      v
 Repository   talks to the database
      |
      v
  H2 database (file: data/todo)
```

## API reference

Base URL: `http://localhost:8080/api/todos`

| Method | Endpoint | Description | Success |
|--------|----------|-------------|---------|
| GET | `/api/todos` | List all todos | `200` |
| GET | `/api/todos?done=true` | List only completed todos (use `false` for open ones) | `200` |
| GET | `/api/todos/{id}` | Get one todo | `200` |
| POST | `/api/todos` | Create a todo | `201` |
| PUT | `/api/todos/{id}` | Update title and/or done status | `200` |
| DELETE | `/api/todos/{id}` | Delete a todo | `204` |

### Todo object

```json
{
  "id": 1,
  "title": "Learn Spring Boot",
  "done": false,
  "createdAt": "2026-11-25T10:30:00.123"
}
```

### Request body (POST and PUT)

| Field | Type | Rules |
|-------|------|-------|
| `title` | string | Required, not blank, at most 100 characters |
| `done` | boolean | Optional. Keeps the current value if omitted |

### Errors

Errors are returned as JSON.

| Situation | Status | Example body |
|-----------|--------|--------------|
| Todo id does not exist | `404` | `{"error":"Todo 99 not found"}` |
| Empty or missing title | `400` | `{"error":"title: title is required"}` |

## Example requests

```bash
# create a todo
curl -i -X POST localhost:8080/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Spring Boot"}'

# list all todos
curl localhost:8080/api/todos

# get one todo
curl localhost:8080/api/todos/1

# mark todo 1 as done
curl -X PUT localhost:8080/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Spring Boot","done":true}'

# list completed todos
curl "localhost:8080/api/todos?done=true"

# delete todo 1
curl -i -X DELETE localhost:8080/api/todos/1
```

## Configuration

Settings live in `src/main/resources/application.properties`:

```properties
server.port=${PORT:8080}
spring.datasource.url=jdbc:h2:file:./data/todo
spring.datasource.username=sa
spring.datasource.password=
spring.jpa.hibernate.ddl-auto=update
spring.h2.console.enabled=true
logging.level.com.example.todo=INFO
```

| Property | Purpose |
|----------|---------|
| `server.port` | Port to listen on. Reads `PORT`, falls back to `8080` |
| `spring.datasource.url` | Where the H2 database file is stored |
| `spring.jpa.hibernate.ddl-auto` | Creates and updates the table automatically |
| `spring.h2.console.enabled` | Turns on the browser database viewer |

## Viewing the database

While the app is running, open <http://localhost:8080/h2-console> and enter:

| Field | Value |
|-------|-------|
| JDBC URL | `jdbc:h2:file:./data/todo` |
| User name | `sa` |
| Password | (leave empty) |

Then run:

```sql
SELECT * FROM TODO;
```

> The H2 console is meant for learning and local development. Turn it off (`spring.h2.console.enabled=false`) before deploying anywhere public.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `release version 17 not supported` | Your JDK is older than 17. Install JDK 17 or newer and check `java -version`. |
| `Port 8080 was already in use` | Stop the other program or start with `PORT=9090`. |
| `415 Unsupported Media Type` | Add `-H "Content-Type: application/json"` to your curl command. |
| H2 console cannot connect | Use exactly `jdbc:h2:file:./data/todo`, and stop any other copy of the app that has the database open. |
| Todos disappeared | The `data/` folder was deleted or the app was started from a different folder. Run it from the project root. |

## Ideas for next steps

- Add a `priority` field (LOW, MEDIUM, HIGH) and show it on the web page
- Add a search endpoint using `findByTitleContainingIgnoreCase`
- Add a "Clear completed" button
- Switch the database from H2 to PostgreSQL by changing the dependency and datasource settings
- Package the app in a Docker image and deploy it with a CI/CD pipeline

## Notes for the repository

Add this line to `.gitignore` so database files are not committed:

```
data/
```

