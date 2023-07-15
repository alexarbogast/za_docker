#!/bin/bash -e

EXECUTABLE_NAME="$(basename $0 | sed 's/\(\..*\)$//')"
NAME=${NAME:-tormach_ros_dev}

_write_out() {
    local tag=$1
    local message="${$1:2}"

    printf "%b" \
            "$tag:: $message\n"
}

usage() {
    _write_out "$EXECUTABLE_NAME USAGE" \
        "Printout of executable help and usage informations\n\n" \
        "$0 [-n NAME] \n" \
        "Execute a command in a running  container:\n" \
        "  -n NAME:  Set container name and hostname to NAME\n" \
        "  -n USER:  Set user that runs container command\n"
}

while getopts :n:u:h ARG; do
    case $ARG in
    n) NAME="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    h)
        usage
        exit 0
        ;;
    :)
        usage
        _write_out "Option -$OPTARG requires an argument\n"
        exit 1
        ;;
    *)
        usage
        _write_out "Illegal option -$OPTARG\n"
        exit 1
        ;;
    esac
done
shift $(($OPTIND - 1))

DOCKER_CLI="$(which docker)"

declare -a default_cmd=("/bin/bash" "--login" "-i")
EXECUTE_COMMAND=${@:-${default_cmd}}

# TODO: setup env variables for X11 forwarding  

set -x
exec ${DOCKER_CLI} exec -it -u $USER ${NAME} $EXECUTE_COMMAND