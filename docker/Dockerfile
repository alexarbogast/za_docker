############################
# build
############################
FROM docker.pathpilot.com/ros_public:noetic-dist-focal-231.81b87dc7 AS build

############################
# base
############################
FROM ros:noetic-robot AS base

RUN apt-get update && apt-get install -qy --no-install-recommends \
  curl \
  python3-catkin-tools \
  python3-crcmod \
  python3-lxml \
  python3-fysom \
  python3-ruamel.yaml \
  python3-future \
  && rm -rf /var/lib/apt/lists/*

# Create a non-root user
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# install ROS packages
RUN apt-get update && apt-get install -qy --no-install-recommends \
    ros-noetic-ros-control \
    ros-noetic-ros-controllers \
    ros-noetic-ros-control-boilerplate \
    && rm -r /var/lib/apt/lists/*

# On Debian, LD_LIBRARY_PATH isn't allowed in setuid programs
RUN echo /opt/ros/${ROS_DISTRO}/lib | \
    tee /etc/ld.so.conf.d/ros-${ROS_DISTRO}.conf \
    ldconfig

RUN curl -1sLf \
        'https://dl.cloudsmith.io/public/machinekit/machinekit-hal/setup.deb.sh' \
        | sudo -E bash && \
    curl -1sLf \
        'https://dl.cloudsmith.io/public/machinekit/machinekit/setup.deb.sh' \
        | sudo -E bash && \
    curl -1sLf \
        'https://dl.cloudsmith.io/public/zultron/hal_ros_control/setup.deb.sh' \
        | sudo -E bash && \
    curl -1sLf \
        'https://dl.cloudsmith.io/public/zultron/etherlabmaster/setup.deb.sh' \
        | sudo -E bash

ARG machinekit_suite_version="0.4.21040-1.git21e4211e4~focal" 
RUN tee /etc/apt/preferences.d/20machinekit-version <<EOF

Package: machinekit-hal
Pin: version ${machinekit_suite_version}
Pin-Priority: 999

Package: machinekit-hal-dev
Pin: version ${machinekit_suite_version}
Pin-Priority: 999
EOF

RUN apt-get update && apt-get install -qy --no-install-recommends \
    etherlabmaster-tools \
    linuxcnc-ethercat \
    machinekit-hal \
    machinekit-hal-dev \
    ros-noetic-hal-hw-interface \
    ros-noetic-ros-pytest \
    && rm -rf /var/lib/apt/lists/*

# copy HAL module libraries from pathpilot image
COPY --from=build \
    /opt/ros/noetic/lib/pll.so \
    /opt/ros/noetic/lib/latency.so \
    /opt/ros/noetic/lib/qc.so \
    /opt/ros/noetic/lib/drive_safety.so \
    /opt/ros/noetic/lib/

# copy HAL device manager ROS package artifacts
COPY --from=build \ 
    /opt/ros/noetic/lib/hal_402_device_mgr \
    /opt/ros/noetic/lib/hal_402_device_mgr/

COPY --from=build \
    /opt/ros/noetic/share/hal_402_device_mgr \
    /opt/ros/noetic/share/hal_402_device_mgr/

COPY --from=build \
    /opt/ros/noetic/lib/python3/dist-packages/hal_402_device_mgr \
    /opt/ros/noetic/lib/python3/dist-packages/hal_402_device_mgr/

# setup entrypoint
COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

############################
# dev
############################
FROM base AS dev

RUN apt-get update && apt-get install -qy --no-install-recommends \
    bash-completion \
    neovim \
    && rm -rf /var/lib/apt/lists/*

ENV TERM=xterm-256color
RUN echo "PS1='\e[92m\u\e[0m@\e[94m\h\e[0m:\e[35m\w\e[0m# '" >> /root/.bashrc
