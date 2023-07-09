FROM ros:noetic-robot

# install APT packages
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    git \
    curl \
    redis-server \
    && rm -rf /var/lib/apt/lists/*

# install ROS packages
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    ros-noetic-moveit \
    ros-noetic-ros-control-boilerplate \
    ros-noetic-ros-controllers \
    ros-noetic-ros-pytest \
    python3-catkin-tools \
    && rm -rf /var/lib/apt/lists/*

# install packages from Cloudsmith repositories
RUN curl -1sLf \
        'https://dl.cloudsmith.io/public/zultron/machinekit/setup.deb.sh' \
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
        
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    ros-noetic-hal-hw-interface \
    machinekit-hal-dev \
    linuxcnc-ethercat --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 120 robotusers && groupadd docker
CMD ["bash", "-l"] 