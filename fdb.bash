#!/bin/bash

# Copyright 2018 Bryant Luk
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Stop the service to make changes.
service foundationdb stop

# Copy back any missing config files from the initial install.
cp -r --no-clobber /etc/foundationdb.default/* /etc/foundationdb

# Setup the listening address which should be 0.0.0.0 for all practical purposes in Docker.
listen_addr=${FDB_LISTEN_ADDR}
sed -i "s/^listen_address.*/listen_address = ${listen_addr}:${FDB_LISTEN_PORT}/" /etc/foundationdb/foundationdb.conf

# Setup the public address which clients and other nodes should connect with.
public_addr=${FDB_PUBLIC_ADDR}
if [[ -z $public_addr ]]; then
  public_addr=$(grep `hostname` /etc/hosts | sed -e "s/\s *`hostname`.*//")
fi
sed -i "s/^public_address.*/public_address = ${public_addr}:${FDB_PUBLIC_PORT}/" /etc/foundationdb/foundationdb.conf

# Replace the locality machine ID, machine ID, and locality zone ID.
sed -i "s/^# machine_id.*/locality_machineid = ${FDB_LOCALITY_MACHINE_ID}\\nmachine_id= ${FDB_LOCALITY_MACHINE_ID}\\nlocality_zoneid = ${FDB_LOCALITY_ZONE_ID}\\n/" /etc/foundationdb/foundationdb.conf

# Reset file permissions on all files and directories especially when using Docker volumes with the host.
groupmod -g ${FDB_GID} --non-unique foundationdb
usermod -g ${FDB_GID} -u ${FDB_UID} --non-unique foundationdb
chown -R foundationdb:foundationdb /etc/foundationdb /var/log/foundationdb /var/lib/foundationdb

if [[ ${FDB_RESET_FDB_CLUSTER_FILE} -eq "1" ]]; then
  # Reset the fdb.cluster to possibly make the cluster public.
  sed -i 's/\(.*\)@\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}\(.*\):\(.*\)/\1@127.0.0.1:\4/' /etc/foundationdb/fdb.cluster

  if [[ ${public_addr} != "127.0.0.1" ]]; then
    /usr/lib/foundationdb/make_public.py -a ${public_addr}
  fi
fi

# Disable autostart of FDB.
update-rc.d foundationdb disable
service foundationdb stop

mkdir -p /var/fdb
chown -R foundationdb:foundationdb /var/fdb

sudo -u foundationdb /usr/lib/foundationdb/fdbmonitor --conffile /etc/foundationdb/foundationdb.conf --lockfile /var/fdb/fdbmonitor.pid
