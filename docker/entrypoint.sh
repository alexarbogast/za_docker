#!/bin/bash
set -e

NAME=$(basename $0 | sed 's/\(\..*\)$//')

_write_out() {
    local tag=$1
    local message="${@:2}"

    printf "%b" \
        "$tag $message\n"
}

log_info() {
    _write_out "[$NAME] [INFO]" "$@"
} >&2
log_warning() {
    _write_out "[$NAME] [WARNING]" "$@"
} >&2
log_error() {
    _write_out "[$NAME] [ERROR]" "$@"
} >&2

add_hostname_to_hosts() {
    local hostname="$1"
    local hosts_file="/etc/hosts"

    echo "127.0.2.1  $hostname" >>${hosts_file}
    local retval="$?"
    if ((retval != 0)); then
        log_error "Cannot add current hostname $hostname to $hosts_file"
        return ${retval}
    fi

    log_info "Hostname $hostname added to the $hosts_file file."

    return 0
}

add_user_to_groups() {
    local user_name="$1"
    local -a user_groups=("${@:2}")
    local retval="-1"

    for grp in "${user_groups[@]}"; do
        sudo adduser ${user_name} ${grp} >&/dev/null
        retval="$?"
        if ((retval != 0)); then
            log_error "Cannot add user $user_name to group $grp"
            return ${retval}
        fi

        log_info "User $user_name added to the group $grp."
    done

    return 0
}

set_machinekit_hal_remote() {
    local remote=${1:-"0"}

    sudo sed -i /etc/machinekit/machinekit.ini \
             -e "\$a ANNOUNCE_IPV4=${remote}\nANNOUNCE_IPV6=${remote}" \
             -e '/^ANNOUNCE_IPV/ d'
    local retval="$?"
    if ((retval != 0)); then
        log_error "Cannot set Machinekit-HAL remote in " \
            "/etc/machinekit/machinekit.ini to $remote"
        return ${retval}
    fi

    log_info "Remote communication of Machinekit-HAL set to $remote."

    return 0
}

# Turn off Machinekit-HAL mDNS announcements; dbus socket not bind-mounted
set_machinekit_hal_remote "0"
retval="$?"
if ((retval != 0)); then
  exit 1 
fi

# base_user_groups=(plugdev)
# add_user_to_groups "ros" "${base_user_groups[@]}"
# retval="$?"
# if ((retval != 0)); then
#   exit 1
# fi
#
# add_hostname_to_hosts "$HOSTNAME"
# if ((retval != 0)); then
#   exit 1
# fi
#
# setup ros environment
source "/opt/ros/$ROS_DISTRO/setup.bash"

exec "$@"
