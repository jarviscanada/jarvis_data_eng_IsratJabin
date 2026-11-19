#!/bin/bash

# Assign PostgreSQL connection arguments
psql_host=$1
psql_port=$2
db_name=$3
psql_user=$4
psql_password=$5

# Validate command-line arguments
if [ "$#" -ne 5 ]; then
    echo "Error: Expected 5 arguments"
    exit 1
fi
# Collect current resource usage
vmstat_mb=$(vmstat --unit M)
hostname=$(hostname -f)
memory_free=$(echo "$vmstat_mb" | tail -1 | awk '{print $4}')
cpu_idle=$(echo "$vmstat_mb" | tail -1 | awk '{print $15}')
cpu_kernel=$(echo "$vmstat_mb" | tail -1 | awk '{print $14}')
disk_io=$(vmstat -d | tail -1 | awk '{print $10}')
disk_available=$(df -BM / | tail -1 | awk '{print $4}' | tr -d 'M')
timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")

# Find the registered host ID using its hostname
host_id="(SELECT id FROM host_info WHERE hostname='$hostname')"
# Construct the SQL statement for resource usage
insert_stmt="INSERT INTO host_usage (\"timestamp\", host_id, memory_free, cpu_idle, cpu_kernel, disk_io, disk_available) VALUES ('$timestamp', $host_id, $memory_free, $cpu_idle, $cpu_kernel, $disk_io, $disk_available);"

# Insert resource usage into PostgreSQL
export PGPASSWORD="$psql_password"
psql -h "$psql_host" -p "$psql_port" -d "$db_name" -U "$psql_user" -v ON_ERROR_STOP=1 -c "$insert_stmt"
exit $?
