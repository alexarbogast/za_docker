FROM docker.pathpilot.com/ros_public:noetic-dist-focal-202.39524b60

# install packages
RUN apt-get update && apt-get upgrade -y --allow-downgrades
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    ros-noetic-moveit \
    ros-noetic-ros-controllers \
    && rm -rf /var/lib/apt/lists/*