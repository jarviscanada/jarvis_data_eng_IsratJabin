#!/bin/bash

# Assign PostgreSQL connection arguments
psql_host=$1
psql_port=$2
db_name=$3
psql_user=$4
psql_password=$5

# Validate the number of arguments
if [ "$#" -ne 5 ]; then
    echo "Error: Expected 5 arguments"
    exit 1
fi

# Collect hardware specifications
hostname=$(hostname -f)
lscpu_out=$(lscpu)
cpu_number=$(echo "$lscpu_out" | grep "^CPU(s):" | awk '{print $2}')
cpu_architecture=$(echo "$lscpu_out" | grep "^Architecture:" | awk '{print $2}')
cpu_model=$(echo "$lscpu_out" | grep "^Model name:" | cut -d ':' -f 2- | xargs)
cpu_mhz=$(grep -m 1 "cpu MHz" /proc/cpuinfo | awk '{print $4}')
l2_cache=$(echo "$lscpu_out" | grep "^L2 cache:" | awk '{print $3}')
total_mem=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
timestamp=$(date -u +"%Y-%m-%d %H:%M:%S")

# Construct the SQL insert statement
insert_stmt="INSERT INTO host_info (hostname, cpu_number, cpu_architecture, cpu_model, cpu_mhz, l2_cache, total_mem, \"timestamp\") VALUES ('$hostname', $cpu_number, '$cpu_architecture', '$cpu_model', $cpu_mhz, $l2_cache, $total_mem, '$timestamp') ON CONFLICT (hostname) DO NOTHING;"

# Insert hardware specifications into PostgreSQL
export PGPASSWORD="$psql_password"
psql -h "$psql_host" -p "$psql_port" -d "$db_name" -U "$psql_user" -v ON_ERROR_STOP=1 -c "$insert_stmt"
exit $?
