# za_docker

A group of tools for developing ros applications for the [Tormach Za6](https://tormach.com/machines/robots.html) manipulator. This package builds a custom docker image that layers on top of the existing `docker.pathpilot.com/ros_public:noetic-dist-focal-202.39524b60` image.

## Building the image
To build the image you must have the base `docker.pathpilot.com/ros_public:noetic-dist-focal-202.39524b60` image or equivalent version installed. *Note: this has only been tested with the image version listed above.* Check your available images with `docker image ls`.

The recommended tag for the image is `tormach_ros_dev`. The [container_bash.sh](container_bash.sh) and [tormach_ros_dev_container.sh](tormach_ros_dev_container.sh) scripts are setup to work with this tag by default.
```sh
cd ./docker
docker build -t tormach_ros_dev .
```

## Running the container
The [tormach_ros_dev_container.sh](tormach_ros_dev_container.sh) script is a modified version of the pathpilot launcher script. It changes the entrypoint of the container to [entrypoint](entypoint) and sets up the necessary environment variables for executing the container in simulation or on the real hardware. 

The container is run as the current user, and the users home directory is mounted as a volume in the container. 

```sh
./tormach_ros_dev_container.sh [-d] [-v] [-t IMAGE] [-n NAME]

-d:  Detach from container (background mode)
-x:  Run the image in execution mode (on real hardware, not sim)
-t IMAGE:  Specify the complete image tag
-n NAME:  Set container name and hostname to NAME
```

The default name is tormach_ros_dev. If no image is specified, the script will attempt to automatically deduce the latest valid image. **Note: If you are not running in simulation, you will need to pass the -x flag so that ethercat is configured properly for [hal_ros_control](https://github.com/tormach/hal_ros_control).**

## Container shells

To get another shell in the container, use the [container_bash.sh](container_bash.sh) script.

```sh
./container_bash.sh [-u USER] [n NAME]

-u Sets the user in the shell (default $USER)
-n Specify the name of the container (defaul tormach_ros_dev) 
```

## Building [ROS](https://www.ros.org/) applications
The [hardware_ws](hardware_ws) is mounted in the container as a volume to facilitate the development of ros applications in the za6 container. Add your ros packages to a `src` folder in the [hardware_ws](hardware_ws) directory.

After starting the container.
```sh
cd hardware_ws
catkin build
```

## Known bugs
The x11 server is not being configured properly in the container, so GUIs will not work until this is fixed. However, it is often best to run the realtime hardware packages in the container and do higher level planning tasks on another machine as the ROS master. This allows you to leverage newer versions of MoveIt and other packages than are currently available in the container.  