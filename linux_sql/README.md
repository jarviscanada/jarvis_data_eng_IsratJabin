# Linux Cluster Monitoring Agent

## Introduction

The Linux Cluster Monitoring Agent is a lightweight monitoring
application designed to collect and store hardware information
and resource usage statistics from Linux servers.

The project helps system administrators and infrastructure teams
understand server configurations and monitor resource utilization
over time. It collects information such as CPU architecture,
processor count, total memory, available memory, CPU utilization,
and disk availability.

The application uses Bash scripts to retrieve system information
and PostgreSQL to store the collected data. PostgreSQL runs inside
a Docker container with persistent storage to preserve database
records. A cron job automatically executes the resource monitoring
script every minute, enabling continuous data collection.

Git and GitHub are used for version control and development
workflow management. The application was implemented and tested
on a Rocky Linux virtual machine hosted on Google Cloud.

## Implementation

### Architecture

The Linux Cluster Monitoring Agent uses Bash scripts, Docker, PostgreSQL, and Cron to collect and store Linux server information.

The application follows a lightweight monitoring architecture in which Linux hosts collect resource measurements and send them to a PostgreSQL database.

```text
              Linux Host (Rocky Linux)
          +-----------------------------+
          |                             |
          |  host_info.sh               |
          |  Collects hardware details  |
          |                             |
          |  Cron Scheduler             |
          |       |                     |
          |       v                     |
          |  host_usage.sh              |
          |  Collects resource usage    |
          |                             |
          +--------------+--------------+
                         |
                         | PostgreSQL connection
                         | localhost:5432
                         v
          +-----------------------------+
          |       Docker Container      |
          |          jrvs-psql          |
          |                             |
          |      PostgreSQL Database    |
          |          host_agent         |
          |                             |
          |  +-----------+------------+ |
          |  | host_info | host_usage | |
          |  +-----------+------------+ |
          +--------------+--------------+
                         |
                         v
                  Docker Volume
                     pgdata
               (Persistent Storage)
```

The `host_info.sh` script registers hardware specifications in the `host_info` table. The `host_usage.sh` script collects resource utilization metrics and inserts them into the `host_usage` table.

Cron runs `host_usage.sh` once every minute to automate monitoring. PostgreSQL runs inside a Docker container, while the `pgdata` Docker volume preserves database files independently of the container lifecycle.

The application was deployed and validated on one Rocky Linux virtual machine. The architecture can be extended to collect monitoring data from multiple Linux servers after configuring remote database access, appropriate network permissions, and authentication.

## Quick Start

### Prerequisites

The application requires:

- A Linux environment with Bash and standard system utilities
- Docker Engine
- PostgreSQL command-line client (`psql`)
- Cron for automated monitoring

### 1. Start PostgreSQL

From the `linux_sql` directory, create the PostgreSQL container. Replace `YOUR_PASSWORD` with your own database password in the example commands below. These command-line password arguments are for local development and may be visible in shell history or process listings:

```bash
./scripts/psql_docker.sh create postgres "YOUR_PASSWORD"
```

If the container already exists but is stopped, run:

```bash
./scripts/psql_docker.sh start
```

### 2. Set up the database

Connect to PostgreSQL:

```bash
psql -h localhost -p 5432 -U postgres -d postgres -W
```

Create the application database:

```sql
CREATE DATABASE host_agent;
```

Exit the PostgreSQL console using `\q`.

Initialize the database tables:

```bash
psql -h localhost -p 5432 -U postgres -d host_agent -W -v ON_ERROR_STOP=1 -f sql/ddl.sql
```

### 3. Register server hardware

Execute the hardware information script:

```bash
./scripts/host_info.sh localhost 5432 host_agent postgres "YOUR_PASSWORD"
```

The script registers the server's hostname, CPU information, and total memory in the `host_info` table.

### 4. Collect resource usage

Execute:

```bash
./scripts/host_usage.sh localhost 5432 host_agent postgres "YOUR_PASSWORD"
```

This collects memory, CPU, and disk measurements and inserts a record into the `host_usage` table.

### 5. Schedule automatic monitoring

Open the cron editor:

```bash
crontab -e
```

Configure a job to run the usage script once per minute (illustrative example only; replace the absolute path and password placeholder before using it):

```cron
* * * * * /bin/bash /absolute/path/to/linux_sql/scripts/host_usage.sh localhost 5432 host_agent postgres "YOUR_PASSWORD" >> /tmp/host_usage.log 2>&1
```

### 6. Verify the collected data

Connect to the application database:

```bash
psql -h localhost -p 5432 -U postgres -d host_agent -W
```

Query the latest monitoring records:

```sql
SELECT * FROM host_usage
ORDER BY "timestamp" DESC
LIMIT 5;
```

The table should contain new records for the registered host after successful execution.

## Scripts

The monitoring application uses three shell scripts to manage the database and collect server information.

#### psql_docker.sh

This script manages the PostgreSQL Docker container named `jrvs-psql`. It checks whether Docker is running, validates command-line arguments, and supports creating, starting, and stopping the database container.

```bash
# Create a new PostgreSQL container
./scripts/psql_docker.sh create postgres "YOUR_PASSWORD"

# Start an existing container
./scripts/psql_docker.sh start

# Stop the container
./scripts/psql_docker.sh stop
```

A named Docker volume, `pgdata`, preserves database files independently of the container.

#### host_info.sh

This script collects the server's hostname, CPU specifications, total memory, and UTC timestamp. It inserts this information into the `host_info` table.

```bash
./scripts/host_info.sh localhost 5432 host_agent postgres "YOUR_PASSWORD"
```

It is designed to register a server once. If the hostname already exists, the script skips the duplicate insertion.

#### host_usage.sh

This script collects available memory, CPU idle percentage, kernel CPU usage, disk I/O, available disk space, and a UTC timestamp.

```bash
./scripts/host_usage.sh localhost 5432 host_agent postgres "YOUR_PASSWORD"
```

It identifies the server through its hostname, retrieves the corresponding `host_id`, and inserts a measurement into `host_usage`.

#### Automated Monitoring with Cron

Cron schedules the usage script to execute once every minute.

```cron
* * * * * /bin/bash /absolute/path/to/linux_sql/scripts/host_usage.sh localhost 5432 host_agent postgres "YOUR_PASSWORD" >> /tmp/host_usage.log 2>&1
```

The log file captures standard output and error messages. **Security note:** The Cron examples above pass a password as a command-line argument and are shown only to explain the current script interface. Avoid storing a real password directly in a crontab entry. For production use, adapt the script to use protected PostgreSQL credentials (for example, a restricted `.pgpass` file) or a secrets manager.

#### queries.sql

The `sql/queries.sql` file is intended for analytical SQL queries against the monitoring data, such as comparing resource usage and identifying servers with limited available resources.

Analytical queries can help infrastructure teams investigate utilization trends and make capacity-planning decisions.

## Database Modeling

The application uses a relational database called `host_agent`, containing two tables: `host_info` and `host_usage`.

The `host_info` table stores relatively static hardware specifications, while `host_usage` stores resource measurements that change over time. The tables are connected through a foreign key, allowing multiple usage records to belong to one registered server.

#### host_info

| Column | Data Type | Constraints | Description |
|---|---|---|---|
| id | SERIAL | Primary key | Unique identifier for a Linux server |
| hostname | VARCHAR | NOT NULL, UNIQUE | Fully qualified hostname |
| cpu_number | SMALLINT | NOT NULL | Number of logical CPUs |
| cpu_architecture | VARCHAR | NOT NULL | CPU architecture |
| cpu_model | VARCHAR | NOT NULL | Processor model |
| cpu_mhz | DOUBLE PRECISION | NOT NULL | CPU frequency in MHz |
| l2_cache | INTEGER | NOT NULL | L2 cache size in KiB |
| timestamp | TIMESTAMP | Nullable | Registration timestamp in UTC |
| total_mem | INTEGER | Nullable | Total system memory in kB |

#### host_usage

| Column | Data Type | Constraints | Description |
|---|---|---|---|
| timestamp | TIMESTAMP | NOT NULL | Time when measurements were collected |
| host_id | INTEGER | NOT NULL, Foreign key | References `host_info.id` |
| memory_free | INTEGER | NOT NULL | Free memory in MB |
| cpu_idle | SMALLINT | NOT NULL | CPU idle percentage |
| cpu_kernel | SMALLINT | NOT NULL | CPU kernel usage percentage |
| disk_io | INTEGER | NOT NULL | Disk I/O operations currently in progress |
| disk_available | INTEGER | NOT NULL | Available disk space in MB |

#### Table Relationship

The relationship between `host_info` and `host_usage` is one-to-many.

Each server has one hardware specification record in `host_info`, but it can have many usage records in `host_usage`.

Using separate tables avoids repeating hardware specifications for every monitoring measurement and supports efficient analysis of server resource usage.

## Testing

The monitoring agent was tested on a Rocky Linux 9 virtual machine using PostgreSQL 17 running inside Docker.

### Bash Script Testing

Both monitoring scripts were checked for syntax errors using:

```bash
bash -n scripts/host_info.sh
bash -n scripts/host_usage.sh
```

Neither command reported syntax errors. Argument validation was also tested by executing the scripts without the required database connection arguments. Both correctly returned an error message.

### Database Integration Testing

The `host_info.sh` script successfully connected to PostgreSQL. When executed for an already registered server, PostgreSQL returned `INSERT 0 0`, confirming that the duplicate hostname was skipped.

The `host_usage.sh` script successfully inserted a new monitoring record. The inserted data was verified by querying the `host_usage` table.

The existing database tables were also checked by executing `sql/ddl.sql` against PostgreSQL. The script completed successfully and skipped tables that already existed.

### Cron Automation Testing

The usage script was scheduled through crontab to run once every minute.

The cron log reported a successful database insertion:

```text
INSERT 0 1
```

A PostgreSQL query confirmed consecutive monitoring records at 08:22:01, 08:23:01, and 08:24:01 UTC on November 18, 2026.

These results verified successful automated data collection at one-minute intervals.

## Deployment

The application was deployed on a Google Cloud virtual machine running Rocky Linux 9.

Docker was used to run PostgreSQL 17 in a container named `jrvs-psql`. A named Docker volume, `pgdata`, was configured to retain database files independently of the container.

The monitoring scripts were executed directly on the Linux host. The `host_info.sh` script registered the server's hardware information, while `host_usage.sh` collected resource measurements.

Cron was configured to execute `host_usage.sh` every minute. The script connected to PostgreSQL through localhost on port 5432 and inserted the collected metrics into the database.

Git and GitHub were used for source control. Development changes were committed on feature branches and integrated into the `develop` branch through pull requests.

The deployment was validated on one Linux virtual machine. The proposed architecture supports collecting data from multiple Linux hosts into a centralized database.

## Improvements

### 1. Secure Database Authentication

The current scripts accept PostgreSQL credentials through command-line arguments. A future improvement would be to use protected credential files or a secrets manager to avoid exposing passwords in shell history, cron configuration, or process information.

### 2. Improve Error Handling and Logging

The monitoring scripts could include structured logging, more detailed validation, and retry mechanisms for temporary database connection failures. This would make troubleshooting easier and improve reliability.

### 3. Improve Monitoring Accuracy

The resource collection process could be enhanced to sample CPU and disk activity over defined intervals, providing more representative utilization measurements.

### 4. Add Automated Testing

Automated integration tests could verify database initialization, successful insertions, error handling, and monitoring script behavior in different environments.

### 5. Support Hardware Changes

The hardware registration script currently skips existing hostnames. Future versions could detect changes to CPU or memory configurations and update existing host records accordingly.
