#!/bin/bash -e

EXECUTABLE_NAME="$(basename $0 | sed 's/\(\..*\)$//')"
HARDWARE_MODE=${HARDWARE_MODE:-"sim"}

_write_out() {
    local tag=$1
    local message="${@:2}"
    local timestamp="$(date +'%Y-%m-%dT%H:%M:%S%z')"

    printf "%b" \
            "$tag::$timestamp:: $message\n"
}

log_info() {
    _write_out "$EXECUTABLE_NAME INFO" "$@"
} >&2
log_error() {
    _write_out "$EXECUTABLE_NAME ERROR" "$@"
} >&2

success() {
    exit 0
} >&2

failure() {
    _write_out "$EXECUTABLE_NAME" "Execution failed!"
    exit ${1:-"1"}
} >&2

usage() {
    _write_out "$EXECUTABLE_NAME USAGE" \
        "Printout of executable help and usage informations\n\n" \
        "$0 [-s] [-d] [-v] [-t IMAGE] [-n NAME] [-r REGISTRY]\n" \
        "Run the launcher container:\n" \
        "  -f:  Report the failure to start the Launcher (red triangle)\n" \
        "  -b:  Detach from container (background mode)\n" \
        "  -d:  Run the distribution image (default mode)\n" \
        "       |-->  Deprecated flag\n" \
        "  -r:  Specify a Docker registry from which start the Launcher\n" \
        "  -t IMAGE:  Specify the complete image tag\n" \
        "  -S:  Use Freedesktop Secret Service for storing secrets\n" \
        "  -n NAME:  Set container name and hostname to NAME\n"
}

DOCKER_CLI="$(which docker)"
DOCKER_RUN_OPTS+=(-e LAUNCHER=1)

if [[ "$DOCKER_CLI" == "" ]]; then
    log_error "Docker CLI executable not found in \${PATH}!" \
        "Do you have Docker installed?"
    failure 4
fi

DOCKER_RUN_OPTS=(${DOCKER_ARGS})
STARTER_RUN_ARGS=()

while getopts :bft:r:n:h ARG; do
    case $ARG in
    b) DOCKER_RUN_OPTS+=("-d") ;;
    f) STARTER_RUN_ARGS+=("-r") ;;
    t) IMAGE="$OPTARG" ;;
    r) DOCKER_REGISTRY="$OPTARG" ;;
    n) NAME="$OPTARG" ;;
    h)
        usage
        success
        ;;
    :)
        usage
        log_error "Option -$OPTARG requires an argument"
        failure
        ;;
    *)
        usage
        log_error "Illegal option -$OPTARG"
        failure
        ;;
    esac
done
shift $(($OPTIND - 1))

# Docker registry used for the launcher
MAIN_DOCKER_REPOSITORY=${MAIN_DOCKER_REPOSITORY:-ros_public}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-docker.pathpilot.com}

# Set params
IMAGE_TYPE=${IMAGE_TYPE:-dist}

DOCKER_TAG_PATTERN="[^-]+-$IMAGE_TYPE-[^-]+-[0-9]+\.[0-9a-f]+$"

# - Image tag (-t)
if ! [[ -v IMAGE ]]; then
    declare -a VALID_IMAGES=()
    declare -a sorted_VALID_IMAGES=()
    DEFAULT_IMAGE=""

    mapfile -t POSSIBLE_IMAGES < <(${DOCKER_CLI} image ls \
        --filter=label=com.tormach.pathpilot.robot.image.type=$IMAGE_TYPE \
        --filter=reference=$DOCKER_REGISTRY/* \
        --format='{{.Repository}}:{{.Tag}}')

    for image in ${POSSIBLE_IMAGES[@]}; do
        if [[ $image =~ $DOCKER_TAG_PATTERN ]]; then
            created="$(${DOCKER_CLI} inspect -f '{{ index .Config.Labels "com.tormach.pathpilot.robot.createdAt"}}' ${image})" 2>&1
            retval="$?"
            if ((retval != 0)); then
                log_error "Command '${DOCKER_CLI} inspect -f '{{ index .Config.Labels " \
                    "\"com.tormach.pathpilot.robot.createdAt\"}}' ${image})' returned " \
                    "error $retval!"
                continue
            fi

            if [[ "$created" == "" ]]; then
                log_error "Label 'com.tormach.pathpilot.robot.createdAt' not set on image '$image'" 2>&1
                created="$(${DOCKER_CLI} inspect -f '{{ index .Created }}' $image)"
                retval="$?"
                if ((retval != 0)); then
                    log_error "${DOCKER_CLI} inspect -f '{{ index .Created }}' $image) " \
                        "returned error $retval!"
                    continue
                fi
            fi
            if [[ "$created" == "" ]]; then
                log_error "Cannot inspect the image for creation date '$image'. Skipping!"
                continue
            fi
            VALID_IMAGES+=("$image;$created")
        fi
    done

    IFS=$'\n' sorted_VALID_IMAGES=($(sort -t\; -k2 -r <<<"${VALID_IMAGES[*]}"))
    unset IFS

    VALID_IMAGES=()

    for image_tuple in ${sorted_VALID_IMAGES[@]}; do
        image=(${image_tuple//;/ })
        VALID_IMAGES+=($image)
    done

    # Prefer the main PathPilot channel for the Robot Launcher before anything else
    for image in ${VALID_IMAGES[@]}; do
        if [[ $image =~ $DOCKER_REGISTRY/$MAIN_DOCKER_REPOSITORY ]]; then
            DEFAULT_IMAGE="$image"
            break
        fi
    done

    if [[ "$DEFAULT_IMAGE" == "" ]]; then
        DEFAULT_IMAGE="${VALID_IMAGES[0]}"
    fi

    IMAGE="$DEFAULT_IMAGE"
fi

# - Container name (-n)
NAME=${NAME:-gt_tormach}

# Run Docker
log_info "Launching Za6 container"
CONTAINER_NAME=${NAME}
DOCKER_RUN_OPTS+=(-e HARDWARE_MODE=${HARDWARE_MODE})
test -z "$DOCKER_CONFIG" || DOCKER_RUN_OPTS+=(-e DOCKER_CONFIG="$DOCKER_CONFIG")
test -z "$DOCKER_REGISTRY" || DOCKER_RUN_OPTS+=(-e DOCKER_REGISTRY="$DOCKER_REGISTRY")
test -z "$ROS_SETUP" || DOCKER_RUN_OPTS+=(-e ROS_SETUP="$ROS_SETUP")

# PathPilot on real display
DOCKER_RUN_OPTS+=(
    -e DISPLAY=:0
    -v /tmp/.X11-unix:/tmp/.X11-unix
    -v /dev/dri:/dev/dri
    --network host
)

# Check for existing containers:  If a container exists, script will
# continue only if it is stopped (& after removing it)
EXISTING="$(docker ps -aq --filter=name=^/${CONTAINER_NAME}$)"
RUNNING=false
if test -n "${EXISTING}"; then
    # Container exists; is it running?
    RUNNING=$(docker inspect $CONTAINER_NAME |
        awk -F '[ ,]+' '/"Running":/ { print $3 }')
    if test "${RUNNING}" = "false"; then
        log_info "Stopped container '${CONTAINER_NAME}' exists; removing"
        ${DOCKER_CLI} rm ${CONTAINER_NAME}
    elif test "${RUNNING}" = "true"; then
        log_error "Container '${CONTAINER_NAME}' already running; exiting"
        failure
    else
        # Something went wrong
        log_error "Error:  unable to determine status of " \
            "existing container '${EXISTING}'"
        failure
    fi
fi

if tty -s; then
    # interactive shell
    DOCKER_INTERACTIVE=-i
fi

if test -n "$XDG_RUNTIME_DIR"; then
    DOCKER_RUN_OPTS+=(-v $XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR)
fi


# Determine user
C_UID=$(id -u)
C_GID=$(id -g)

# Test if IMAGE to run exists
if [[ -v IMAGE && "$IMAGE" != "" ]]; then
    log_info "Starting container from image $IMAGE"
else
    log_error "ERROR: No runnable image found!"
    failure 5
fi


# Run the launcher container
set -x
exec ${DO} ${DOCKER_CLI} run --rm \
    ${DOCKER_INTERACTIVE} \
    -t --privileged \
    -e UID=${C_UID} \
    -e GID=${C_GID} \
    -e QT_X11_NO_MITSHM=1 \
    -e XDG_RUNTIME_DIR \
    -e HOME \
    -e USER \
    -e TERM \
    -e HARDWARE_MODE \
    -e CURRENT_BASE_OS_VENDOR="$(. /etc/os-release && echo $ID)" \
    -e CURRENT_BASE_OS_DEBIAN_SUITE="$(. /etc/os-release && echo $VERSION_CODENAME)" \
    -e DBUS_SESSION_BUS_ADDRESS \
    -v $HOME:$HOME \
    -v $PWD:$PWD \
    -v /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w $PWD \
    -h ${CONTAINER_NAME} --name ${CONTAINER_NAME} \
    "${DOCKER_RUN_OPTS[@]}" \
    --entrypoint ./entrypoint \
    ${IMAGE} "$@"