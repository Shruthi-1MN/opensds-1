#!/bin/bash

# Copyright (c) 2018 Huawei Technologies Co., Ltd. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# OpenSDS relative operation.

_XTRACE_OPENSDS=$(set +o | grep xtrace)
set +o xtrace


osds:opensds:configuration(){
# Set global configuration.
cat >> $OPENSDS_CONFIG_DIR/opensds.conf << OPENSDS_GLOBAL_CONFIG_DOC
[osdsapiserver]
api_endpoint = 0.0.0.0:50040
auth_strategy = $OPENSDS_AUTH_STRATEGY
# If https is enabled, the default value of cert file
# is /opt/opensds-security/opensds/opensds-cert.pem, 
# and key file is /opt/opensds-security/opensds/opensds-key.pem
https_enabled = False
beego_https_cert_file =
beego_https_key_file =

[osdslet]
api_endpoint = $HOST_IP:50049

[osdsdock]
api_endpoint = $HOST_IP:50050
# Specify which backends should be enabled, sample,ceph,cinder,lvm and so on.
enabled_backends = $OPENSDS_BACKEND_LIST

[database]
endpoint = $HOST_IP:$ETCD_PORT,$HOST_IP:$ETCD_PEER_PORT
driver = etcd

OPENSDS_GLOBAL_CONFIG_DOC
}

osds::opensds::install(){
    osds:opensds:configuration
# Run osdsdock and osdslet daemon in background.
(
    cd ${OPENSDS_DIR}
    sudo build/out/bin/osdsapiserver --daemon
    sudo build/out/bin/osdslet --daemon
    sudo build/out/bin/osdsdock --daemon

    osds::echo_summary "Waiting for osdsapiserver to come up."
    osds::util::wait_for_url localhost:50040 "osdsapiserver" 0.25 80
    if [ $OPENSDS_AUTH_STRATEGY == "keystone" ]; then
        local xtrace
        xtrace=$(set +o | grep xtrace)
        set +o xtrace
        source $DEV_STACK_DIR/openrc admin admin
        $xtrace
    fi

    # Copy bash completion script to system.
    cp ${OPENSDS_DIR}/osdsctl/completion/osdsctl.bash_completion /etc/bash_completion.d/

    export OPENSDS_AUTH_STRATEGY=$OPENSDS_AUTH_STRATEGY
    export OPENSDS_ENDPOINT=http://localhost:50040
    build/out/bin/osdsctl profile create '{"name": "default", "description": "default policy"}'
    if [ $? == 0 ]; then
        osds::echo_summary devsds installed successfully !!
    fi
)
}

osds::opensds::cleanup() {
    sudo killall -9 osdsapiserver osdslet osdsdock &>/dev/null
}

osds::opensds::uninstall(){
     : # Do nothing
}

osds::opensds::uninstall_purge(){
     : # Do nothing
}

# Restore xtrace
$_XTRACE_OPENSDS
