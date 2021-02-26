#! /bin/bash

set -e
set -x

# add bits to install emirge.sh

git fetch https://github.com/illinois-ceesd/mirgecom.git y1_production:y1_production
git checkout master
git branch -D temp || true
git switch -c temp
git merge y1_production

source ~/pack/emirge/miniforge3/bin/activate ceesd

echo RUNNING
rm -Rf CEESD-Y1_nozzle
git clone https://github.com/anderson2981/CEESD-Y1_nozzle.git
cd CEESD-Y1_nozzle/startup
PYOPENCL_TEST=port:pthread python -m mpi4py nozzle.py

eval $(ssh-agent)

# requires SSH private key in file timing-key
# requires corresponding public key in
# https://github.com/illinois-ceesd/timing/settings/keys/new
ssh-add timing-key.pub

git clone git@github.com:illinois-ceesd/timing.git

cat timing/y1-nozzle-timings.txt >> CEESD-Y1_nozzle/startup/case-time.txt
(cd timing && git commit -m "Automatic commit $(date)" && git push)
