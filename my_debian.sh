#!/bin/bash

# Variables needed for further execution
#
# $NEED_ROOT: true/false depending if this script should be run as root or not
NEED_ROOT=true
#
# $VERSION: Version of this script
VERSION=2.0
#
# $RELEASE_DATE: release date of this script
RELEASE_DATE="04 JULY 2023"
#
# $AUTHOR: Author of this script
AUTHOR="leandre.bla@gmail.com"
#
# $AVERAGE_EXECUTION_TIME: On average, the execution time of this script
AVERAGE_EXECUTION_TIME="15min"
#
#
# ===Setup of internal variables and working directory===

SCRIPT_PATH=$(realpath $0)

ORIGINAL_PATH=$(realpath .)

SCRIPT_DIRECTORY=$(dirname $SCRIPT_PATH)

cd $SCRIPT_DIRECTORY

# isatty() and applying colors depending on it
if [ -t 0 ]; then
    IS_TTY=true
    GREEN=`tput setaf 2`
    RED=`tput setaf 1`
    YELLOW=`tput setaf 3`
    NO_COLOR=`tput sgr0`
else
    IS_TTY=false
fi

# Verifying if a log file was provided by an upper script calling this one, in this case, we inheritate it
if [[ -z $LOG_FILE ]]; then
    ROOT_SCRIPT=TRUE
    export LOG_FILE=`realpath .$(basename ${SCRIPT_PATH%%.*}.log)`
else
    unset ROOT_SCRIPT
fi

# Verifying the need for privileges and seeking them
if [[ $NEED_ROOT == "true" && `id -u` -ne 0 ]]; then
    echo "$RED"This script must be run with sudo"$NO_COLOR"
    exit 1
fi

# Logging script informations
echo "$SCRIPT_PATH"
echo `date '+%Y-%m-%d %H:%M'`
echo "Author: $AUTHOR"
echo "v$VERSION"
echo "Average execution time: $AVERAGE_EXECUTION_TIME"
echo "Log file available at $LOG_FILE"

log() {
    echo "[`date '+%Y-%m-%d %H:%M'`] $@" >> $LOG_FILE
    echo "[`date '+%Y-%m-%d %H:%M'`] $@"
}

log [`date '+%Y-%m-%d %H:%M'`] "$SCRIPT_PATH"
log [`date '+%Y-%m-%d %H:%M'`] "Author: $AUTHOR, $SCRIPT_PATH version $VERSION"
log [`date '+%Y-%m-%d %H:%M'`] "Average execution time: $AVERAGE_EXECUTION_TIME"
log [`date '+%Y-%m-%d %H:%M'`] "Log file available at $LOG_FILE"

check_error() {
    local MESSAGE=$1
    local EXIT_CODE=$2
    shift
    shift
    local COMMAND=$@
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR: command \"$COMMAND\" exited with exit code $EXIT_CODE"
        log $MESSAGE: [$RED"KO"$NO_COLOR]
        log "$SCRIPT_PATH failed, see $LOG_FILE for more informations."
        exit 1
    fi
    log $MESSAGE: [$GREEN"OK"$NO_COLOR]
}

try() {
    local MESSAGE=$1
    shift
    log "executing: $@"
    $@ 3>&1 &>>$LOG_FILE 1> >(tee -a >(cat >&3))
    local EXIT_CODE=$?
    check_error "$MESSAGE" "$EXIT_CODE" $@
}

try_as() {
    local MESSAGE=$1
    local USER_AS=$2
    shift
    shift
    try "$MESSAGE" sudo -u $USER_AS $@
}

try_as_current_user() {
    local MESSAGE=$1
    shift
    try_as "$MESSAGE" $SUDO_USER $@
}

ask_yes_no() {
    local PROMPT=$@
    read -p "$PROMPT [Y/n]" ANSWER

    case $ANSWER in
        [Yy]* )
        echo "y"
        ;;
        "")
        echo "y"
        ;;
        * )
        echo "n"
        ;;
    esac
}

repeat() {
    local MESSAGE=$1
    local COUNT=$2
    local I=0
    while [[ $I -le $COUNT ]]; do
        echo -ne "$MESSAGE"
        I=$((I + 1))
    done
}

separating_banner() {
    local MESSAGE=$@
    local COLUMNS=$((`tput cols` - 2))
    local MESSAGE_LENGTH=${#MESSAGE}
    local DIFFERENCE=$[COLUMNS - MESSAGE_LENGTH]
    local PADDING_LEFT=$[DIFFERENCE / 2]
    repeat "=" $COLUMNS
    echo $YELLOW
    repeat " " $PADDING_LEFT
    echo $MESSAGE $NO_COLOR
    repeat "=" $COLUMNS
    echo
}

command_exists() {
    local COMMAND=$1
    if ! [ -x "$(command -v $COMMAND)" ]; then
        echo false
    fi
    echo true
}

# ===Variables===
#
# $SCRIPT_PATH: original path of this script
#
# $ORIGINAL_PATH: original path from where this script was executed
#
# $SCRIPT_DIRECTORY: folder in which this script can be found
#
# $GREEN: ansi color green
#
# $RED: ansi color red
#
# $YELLOW: ansi color yellow
#
# $NO_COLOR: ansi reset color
#
# $IS_TTY: true/false if this script is run in a tty
#
# ===Functions===
#
# log(message...): log all the passed arguments both in the terminal and in the log file
#
# try(explanation_of_the_command, command...): log, execute (as the user who launched this script, root if sudo)
#                                              and verify the output of the command if it fails, the program will exit
#
# try_as(explanation_of_the_command, username, command...): log, execute (as the user passed in argument)
#                                              and verify the output of the command if it fails, the program will exit
#
# try_as_current_user(explanation_of_the_command, command...): log, execute (as the user who really started this script)
#                                              and verify the output of the command if it fails, the program will exit
#
# ask_yes_no(prompt): prompt a message asking the user for yes/or no, it returns a string "y" or "n"
#
# check_error(message, exit_code, command...): check if the exit code is 0 or not, it will then display
#                                              a message and exit the script if the command failed,
#                                              it's useful when the command contains redirections
#                                              and pipes and can't be used in a "try" functions
#
# separating_banner(message...): print a little separating banner with a message in the middle
#
# command_exists(command): prints true or false if the command exists or not
#
# ===Code===
# Insert your code here

if [[ IS_TTY == "true" ]]; then
    APT_COMMAND="apt"
else
    APT_COMMAND="apt-get"
fi

USER_HOME=/home/$SUDO_USER

separating_banner Updating and installing debian default softwares and dependencies
try "Updating apt" $APT_COMMAND update
try "Installing default apt softwares and dependencies" $APT_COMMAND install -y build-essential zsh terminator wget curl valgrind python3 git zip xz-utils

separating_banner "oh-my-zsh"
sudo -u $SUDO_USER sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
check_error "Installing oh-my-zsh" $!

EXPORT_LINE="export PATH=\$PATH:$USER_HOME/.local/bin"
ZSHRC_FILE=$USER_HOME/.zshrc
grep "$EXPORT_LINE" $ZSHRC_FILE
if [[ $? -eq 1 ]]; then
    echo $EXPORT_LINE >> $ZSHRC_FILE
    check_error "Adding $USER_HOME/.local/bin directory to \$PATH" $?
fi

if [[ `command_exists add-apt-repository` == false ]]; then
    separating_banner "GNU Compilation Collection (GCC)"
    try "Add GCC 11 repository" add-apt-repository -y ppa:ubuntu-toolchain-r/test
    try "Add alternative for gcc-8" update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 10
    try "Add alternative for gcc-9" update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 20
    try "Add alternative for gcc-11" update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 30

    try "Add alternative for g++-9" update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 20
    try "Add alternative for g++-11" update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 30

    try "Add alternative for cc" update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30
    try "Set alternative for cc" update-alternatives --set cc /usr/bin/gcc

    try "Add alternative for c++" update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30
    try "Set alternative for c++" update-alternatives --set c++ /usr/bin/g++
fi


separating_banner SSH Server
RESPONSE=`ask_yes_no Do you want to install ssh-server on this machine ?`
if [[ $RESPONSE == "y" ]]; then
    try "Installing openssh" $APT_COMMAND install -y openssh-server
    try "Setting up openssh" systemctl enable ssh
    try "Starting openssh" systemctl start ssh
else
    log "Skipping ssh-server"
fi

separating_banner VSCode
RESPONSE=`ask_yes_no Do You want to install Visual Studio Code on this machine ?`
if [[ $RESPONSE == "y" ]]; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    check_error "Downloading VSCode pgp keys" $? "wget -qO- https://packages.microsoft.com/keys/microsoft.asc"

    try "Installing VSCode pgp keys" install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    check_error "Setting up VSCode repository" $? 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

    try "Removing temporary pgp keys" rm -f packages.microsoft.gpg

    try "Installing apt plugin for https" $APT_COMMAND install -y apt-transport-https
    try "Updating apt" $APT_COMMAND update
    try "Installing VSCode" $APT_COMMAND install -y code
else
    log "Skipping VScode"
fi

separating_banner NodeJS
RESPONSE=`ask_yes_no Do you want to install NodeJS \(node, npm, npx\) on this machine ?`
if [[ $RESPONSE == "y" ]]; then
    NODE_SOURCE_LIST=/etc/apt/sources.list.d/nodesource.list
    if [[ -f $NODE_SOURCE_LIST ]]; then
        try "Removing previous node installation" rm -f $NODE_SOURCE_LIST
    fi
    log "Installing NodeJS repository"
    bash -c "$(curl -fsSL https://deb.nodesource.com/setup_20.x)"
    check_error "Installing NodeJS repository" $!
    try "Updating apt" $APT_COMMAND update
    try "Installing node" $APT_COMMAND install nodejs -y
else
    log "Skipping NodeJS"
fi

separating_banner "Applying default configurations"
REPOSITORY_CONFIG_FOLDER=./config
USER_CONFIG_FOLDER=$USER_HOME/.config
try_as_current_user "Creating config folder if not existing" mkdir -p $USER_CONFIG_FOLDER
try_as_current_user "Copying configuration files" cp -r $REPOSITORY_CONFIG_FOLDER/* $USER_CONFIG_FOLDER
try "Applying ownership on files" chown -R $SUDO_USER:$SUDO_USER $USER_CONFIG_FOLDER

separating_banner "Cleaning up"
try "Removing apt unused/old packages" $APT_COMMAND autoremove -y

separating_banner "Upgrading all installed packages"
try "Updating apt" $APT_COMMAND update
try "Upgrading apt" $APT_COMMAND upgrade -y

log $GREEN"Installation succeed"$NO_COLOR

# ===End===
log "$SCRIPT_PATH finished"
