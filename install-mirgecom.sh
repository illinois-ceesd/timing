#!/bin/bash

set -e
set -x
set -o pipefail

date

MIRGE_BRANCH=${1:-${MIRGE_BRANCH:-"main"}}
TIMING_ENV_NAME=${2:-${TIMING_ENV_NAME:-"timing.main"}}

# -- Install conda env, dependencies and MIRGE-Com via *emirge*
# --- remove old run if it exists
if [ -f "INSTALL_MIRGECOM" ]
then
    if [ -d "emirge" ]
    then
        echo "Removing old MIRGE-Com installation."
        mv -f emirge emirge.old
        rm -rf emirge.old &
    fi

    # --- grab emirge and install MIRGE-Com 
    git clone -b install-with-ssh https://github.com/illinois-ceesd/emirge.git
    cd emirge
    ./install.sh --branch=${MIRGE_BRANCH} --env-name=${TIMING_ENV_NAME}
    cd ../
    if [ -d "emirge/grudge" ]
    then
        echo "MIRGE-Com installed, removing INSTALL_MIRGECOM directive."
        rm -f INSTALL_MIRGECOM
    else
        echo "MIRGE-Com installation failed."
        exit 1
    fi
else
     echo "Did not find INSTALL_MIRGECOM (touch INSTALL_MIRGECOM to really install)"
     echo "Dry run commands:"
     echo "git clone -b install-with-ssh https://github.com/illinois-ceesd/emirge.git"
     echo "./install.sh --branch=${MIRGE_BRANCH} --env-name=${TIMING_ENV_NAME}"
fi

export EMIRGE_HOME="${TIMING_HOME}/emirge"
# source ${EMIRGE_HOME}/config/activate_env.sh
cd emirge/mirgecom
# -- Grab and merge the branch with the case-dependent features
export MIRGE_HASH=$(git rev-parse origin/${MIRGE_BRANCH})
export Y4_HASH="$MIRGE_HASH"
cd ../..

date
