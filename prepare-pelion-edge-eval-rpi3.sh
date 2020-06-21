#!/bin/bash

#
# Build Environment preperation for evaluate Pelion Edge on Raspberry Pi3
#

DEPENDENT_PACKAGES='
    apt-transport-https
    ca-certificates
    curl
    gnupg-agent
    software-properties-common
    gawk
    wget
    git-core
    diffstat
    unzip
    texinfo
    gcc-multilib
    build-essential
    chrpath
    socat
    cpio
    python3
    python3-pip
    python3-pexpect
    xz-utils
    debianutils
    iputils-ping
    libsdl1.2-dev
    xterm
'

DOCKER_PACKAGES='
    docker-ce
    docker-ce-cli
    containerd.io
'

DOCKER_UBUNTU_PACKAGES='
    docker
    docker-engine
    docker.io
    containerd
    runc
'

DOCKER_APT_REPOSITORY='download.docker.com'
DOCKER_APT_FINGERPRINT='0EBFCD88'

REPO_MANIFEST_PELION_EDGE_URL='ssh://git@github.com/armpelionedge/manifest-pelion-edge.git'
REPO_MANIFEST_PELION_EDGE_BRANCH='2.0.0-rc1'

MANIFEST_VID_DEFAULT='42fa7b48-1a65-43aa-890f-8c704daade54'
MANIFEST_CID_DEFAULT='c56f3a62-b52b-4ef6-95a0-db7a6e3b5b21'
MANIFEST_VID=${MANIFEST_VID_DEFAULT}
MANIFEST_CID=${MANIFEST_CID_DEFAULT}

CWD=${PWD}
RET=0

### Functions

function is_package_already_installed() {
    dpkg -l $1 | grep ^ii > /dev/null
    return $?
}

function info() {
    echo "--- $@"
}

function err() {
    echo "$@" >& 2
}

function stop_if_error() {
    local ret
    ret=$1
    if [ $ret != 0 ]; then
        err "Error code $ret returned. Stopped."
        cd ${CWD}
        exit -1
    fi
}

### Main

if [ ${UID} = 0 ]; then
    err "Can't execute on root."
    exit -1
fi

function usage() {
    err "Usage: $0 <[-b bootstrap_credential_file] [-d working_directory]> [-v manifest_file_vendor_ID] [-c manifest_file_class_ID] -p"
    echo ""
    echo "Options:"
    echo "-b : Bootstrap Credential File. (e.g. ./mbed_cloud_dev_credentials.c)"
    echo "-d : Working Directory (e.g. ./build)"
    echo "-v : Vendor GUID for manifest-tool (default: ${MANIFEST_VID_DEFAULT})"
    echo "-c : Class GUID for manifest-tool (default: ${MANIFEST_CID_DEFAULT})"
    echo "-p : Use https instead of git/ssh protocol"
    exit 1
}

while getopts b:d:v:c:ph OPT
do
    case $OPT in
        b) BOOTSTRAP_CREDENTIAL_FILE=${CWD}/$OPTARG
            ;;
        d) WORKING_DIRECTORY=${CWD}/$OPTARG
            ;;
        v) MANIFEST_VID=$OPTARG
            ;;
        c) MANIFEST_CID=$OPTARG
            ;;
        p) USE_HTTPS=1
            ;;
        h) usage
            ;;
        \?) usage
            ;;
    esac
done

if [ -z "${BOOTSTRAP_CREDENTIAL_FILE}" ]; then
    err "Option -b must be specify."
    usage
fi

if [ -z "${WORKING_DIRECTORY}" ]; then
    err "Option -d must be specify."
    usage
fi

info "Checking Bootstrap Credentail File is exist."
if [ ! -f ${BOOTSTRAP_CREDENTIAL_FILE} ]; then
    err "File ${BOOTSTRAP_CREDENTIAL_FILE} is not exist."
    exit 1
else
    info "OK. Bootstrap Credential File is exist."
fi

info "Checking working directrory."
if [ ! -d ${WORKING_DIRECTORY} ]; then
    info "${WORKING_DIRECTORY} is not exist. Create it."
    info " \$ mkdir -p ${WORKING_DIRECTORY}"
    mkdir -p ${WORKING_DIRECTORY}
    stop_if_error $?
else
    info "OK. Working Directory is exist."
fi

info "Checking dpkg is available."
dpkg --version > /dev/null
RET=$?
if [ $RET != 0 ]; then
    err "Failed to execute dpkg."
    exit -1
else
    info "OK. dpkg is available."
fi

PACKAGES_REQUIRE_INSTALL=''
info "Finding packages that require install."
for p in ${DEPENDENT_PACKAGES}
do
    is_package_already_installed $p
    RET=$?
    if [ $RET = 0 ]; then
        info "Package '$p' is already installed."
    else
        info "Package '$p' is not installed."
        PACKAGES_REQUIRE_INSTALL+="$p "
    fi
done
if [ -n "${PACKAGES_REQUIRE_INSTALL}" ]; then
    info "Packeges that require install : ${PACKAGE_REQUIRE_INSTALL}"
    info "Updating repository database."
    info " \$ sudo apt update"
    info "Please input password of sudo when asked for a password."
    sudo apt update -y
    stop_if_error $?
    info "Installing require packages."
    info " \$ sudo apt install ${PACKAGES_REQUIRE_INSTALL}"
    info "Please input password of sudo when asked for a password."
    sudo apt install -y ${PACKAGES_REQUIRE_INSTALL}
    stop_if_error $?
else
    info "OK. All packages are already installed."
fi

info "Checking whether repository list contains ${DOCKER_APT_REPOSITORY} repository."
HAVE_DOCKER_APT_REPOSITORY=0
SOURCES_LISTS=$(find /etc/apt -name '*.list')
for s in ${SOURCES_LISTS}
do
    grep -v '^#' $s | grep ${DOCKER_APT_REPOSITORY} > /dev/null
    RET=$?
    if [ $RET = 0 ]; then
        HAVE_DOCKER_APT_REPOSITORY=1
        break
    elif [ $RET = 2 ]; then
        err "Check failed."
        exit -1
    fi
done
if [ ${HAVE_DOCKER_APT_REPOSITORY} = 0 ]; then
    info "Checking whether Docker packages are already installed from Ubuntu repository."
    for p in ${DOCKER_UBUNTU_PACKAGES}
    do
        is_package_already_installed $p
        RET=$?
        if [ $RET = 0 ]; then
            err "Package '$p' is already installed from Ubuntu repository."
            err "Docker should be installed from ${DOCKER_APT_REPOSITORY}."
            err "Please confirm that is no problem, and uninstall Docker packages manually."
            err " sudo apt remove ${DOCKER_UBUNTU_PACKAGES}"
            exit -1
        fi
    done
    info "Adding ${DOCKER_APT_REPOSITORY} into sources.list."
    info " \$ curl -fsSL https://${DOCKER_APT_REPOSITORY}/linux/ubuntu/gpg | sudo apt-key add --"
    curl -fsSL https://${DOCKER_APT_REPOSITORY}/linux/ubuntu/gpg | sudo apt-key add --
    stop_if_error $?
    info " \$ sudo apt-key fingerprint ${DOCKER_APT_FINGERPRINT}"
    info "Please input password of sudo when asked for a password."
    sudo apt-key fingerprint ${DOCKER_APT_FINGERPRINT}
    stop_if_error $?
    info " \$ sudo add-apt-repository \"deb [arch=amd64] https://${DOCKER_APT_REPOSITORY}/linux/ubuntu $(lsb_release -cs) stable\""
    info "Please input password of sudo when asked for a password."
    sudo add-apt-repository "deb [arch=amd64] https://${DOCKER_APT_REPOSITORY}/linux/ubuntu $(lsb_release -cs) stable" 
    stop_if_error $?
else
    info "OK. Repository list contains ${DOCKER_APT_REPOSITORY}."
fi

DOCKER_PACKAGES_REQUIRE_INSTALL=''
info "Finding packages that require install."
for p in ${DOCKER_PACKAGES}
do
    is_package_already_installed $p
    RET=$?
    if [ $RET = 0 ]; then
        info "Package '$p' is already installed."
    else
        info "Package '$p' is not installed."
        DOCKER_PACKAGES_REQUIRE_INSTALL+="$p "
    fi
done
if [ -n "${DOCKER_PACKAGES_REQUIRE_INSTALL}" ]; then
    info "Packeges that require install : ${DOCKER_PACKAGES_REQUIRE_INSTALL}"
    info "Updating repository database."
    info " \$ sudo apt update"
    info "Please input password of sudo when asked for a password."
    sudo apt update -y
    stop_if_error $?
    info "Installing require packages."
    info " \$ sudo apt install ${DOCKER_PACKAGES_REQUIRE_INSTALL}"
    info "Please input password of sudo when asked for a password."
    sudo apt install -y ${DOCKER_PACKAGES_REQUIRE_INSTALL}
    stop_if_error $?
else
    info "OK. All packages are already installed."
fi

info "Checking wheather group \"docker\" is exist."
getent group docker > /dev/null
RET=$?
if [ $RET = 2 ]; then
    info "group \"docker\" is not exist."
    info " \$ sudo groupadd docker"
    info "Please input password of sudo when asked for a password."
    sudo groupadd docker
    stop_if_error $?
elif [ $RET = 0 ]; then
    info "OK. Group \"docker\" is already exist."
else
    stop_if_error $?
fi

info "Checking wheather group \"docker\" contains user \"$USER\"."
USER_GROUPS=$(groups)
stop_if_error $?
GROUP_CONTAINS_USER=0
for g in ${USER_GROUPS}
do
    if [ $g = "docker" ]; then
        GROUP_CONTAINS_USER=1
        break
    fi
done
if [ ${GROUP_CONTAINS_USER} = 0 ]; then
    info "group \"docker\" does not contains user \"$USER\"."
    info " \$ sudo usermod -aG docker $USER"
    info "Please input password of sudo when asked for a password."
    sudo usermod -aG docker $USER
    stop_if_error $?
    info "OK. Please reboot system and run this script again."
    exit 0
else
    info "OK. Group \"docker\" contains user \"$USER\"."
fi

info "Checking wheather Docker is runnable."
info " \$ docker run hello-world"
docker run hello-world > /dev/null
stop_if_error $?
info "OK. Docker is runnable."

info "Checking wheather Git is runnable."
git help > /dev/null
stop_if_error $?
info "OK. Git is runnable."

info "Checking git config."
GIT_USERNAME=$(git config --global user.name)
if [ -z "${GIT_USERNAME}" ]; then
    while [ -z "${GIT_USERNAME}" ]
    do
        info "git config -- global user.name is empty. Please input name."
        read GIT_USERNAME
    done
    info " \$ git config --global user.name \"${GIT_USERNAME}\""
    git config --global user.name "${GIT_USERNAME}"
    stop_if_error $?
fi
info "OK. User name is ${GIT_USERNAME}."
GIT_EMAIL=$(git config --global user.email)
if [ -z "${GIT_EMAIL}" ]; then
    while [ -z "${GIT_EMAIL}" ]
    do
        info "git config -- global user.email is empty. Please input name."
        read GIT_EMAIL
    done
    info " \$ git config --global user.email \"${GIT_EMAIL}\""
    git config --global user.email "${GIT_EMAIL}"
    stop_if_error $?
fi
info "OK. User name is ${GIT_EMAIL}."

if [ ${USE_HTTPS} ]; then
    info "Option -p is specified. Use https instead of git/ssh."
    info "Note Git global configuration will be updated by this script."
    info " \$ git config --global url."https://github.com".insteadof ssh://git@github.com"
    git config --global url."https://github.com".insteadof ssh://git@github.com
    stop_if_error $?
    info " \$ git config --global url."https://github.com/".insteadof git@github.com:"
    git config --global url."https://github.com/".insteadof git@github.com:
    stop_if_error $?
fi

cd ${WORKING_DIRECTORY}

info "Checking Repo."
if [ ! -f "repo" ]; then
    info "Downloading Repo"
    info " \$ curl -o repo https://storage.googleapis.com/git-repo-downloads/repo"
    curl -o repo https://storage.googleapis.com/git-repo-downloads/repo
    stop_if_error $?
fi
info "OK. Repo is available."

info "Intializing Repo."
if [ ! ${USE_HTTPS} ]; then
    info "Note \"repo init\" will be failed if your SSH public key is not registered into your GitHub account yet."
fi
info " \$ python3 repo init -u ${REPO_MANIFEST_PELION_EDGE_URL} -b ${REPO_MANIFEST_PELION_EDGE_BRANCH}"
python3 repo init -u ${REPO_MANIFEST_PELION_EDGE_URL} -b ${REPO_MANIFEST_PELION_EDGE_BRANCH}
stop_if_error $?
info "OK. Intialized."

info "Syncing Repo."
info " \$ python3 repo sync -v"
python3 repo sync -v
stop_if_error $?
info "OK. Synced."

info "Copying Bootstarp Credential."
info " \$ cp ${BOOTSTRAP_CREDENTIAL_FILE} ${PWD}/build-env/"
cp ${BOOTSTRAP_CREDENTIAL_FILE} ${PWD}/build-env/
stop_if_error $?
info "OK. Copied."

info "Checking wheather manifest-tool is avalialbe."
pip3 list --format=columns | grep -w manifest-tool > /dev/null
RET=$?
if [ $RET = 1 ]; then
    info "Installing manifest-tool is required."
    info " \$ pip3 install manifest-tool --user"
    pip3 install manifest-tool --user
    stop_if_error $?
elif [ $RET = 0 ]; then
    info "OK. manifest-tool is available."
else
    stop_if_error $RET
fi

cd build-env

info "Generating certificate."
info " \$ ${HOME}/.local/bin/manifest-tool init -V ${MANIFEST_VID} -C ${MANIFEST_CID} -q -f"
${HOME}/.local/bin/manifest-tool init -V ${MANIFEST_VID} -C ${MANIFEST_CID} -q -f
stop_if_error $?
info "OK. Generated."

cd ..

if [ ${USE_HTTPS} ]; then
    info "Option -p is specified. Update ${PWD}/poky/meta-nodejs/classes/npm-base.bbclass for workaround."
    sed -i -e "s/^[ \t]*export HOME/#&/g" ${PWD}/poky/meta-nodejs/classes/npm-base.bbclass
    stop_if_error $?
    info "Please check following diffs."
    cd ${PWD}/poky/meta-nodejs
    git diff
    stop_if_error $?
    cd - > /dev/null
    info "Please execute \"git checkout -- npm-base.bbclass\" on ${PWD}/poky/meta-nodejs/classes when you need revert this change."
    info "Option -p is specified. Update ${PWD}/build-env/Makefile for workaround."
    grep '\-v\s${HOME}/.gitconfig' ${PWD}/build-env/Makefile > /dev/null
    RET=$?
    if [ $RET = 1 ]; then
        sed -i -e '/\s-v ${POKY}:${HOME}\/poky/i\\t\t-v ${HOME}/.gitconfig:${HOME}/.gitconfig \\' ${PWD}/build-env/Makefile
        stop_if_error $?
    elif [ $RET = 0 ]; then
        info "Already applied workaround in ${PWD}/build-env/Makefile"
    else
        stop_if_error $RET
    fi
    info "Please check following diffs."
    cd ${PWD}/build-env
    git diff
    stop_if_error $?
    cd - > /dev/null
    info "Please execute \"git checkout -- Makefile\" on ${PWD}/build-env when you need revert this change."
fi

info "OK. Try execute \"make\" on ${PWD}/build-env."

cd ${CWD}
