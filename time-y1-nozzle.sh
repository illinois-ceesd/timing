#! /bin/bash

set -e
set -x

git clone https://github.com/illinois-ceesd/emirge.git
cd emirge
./install.sh

source ./miniforge3/bin/activate ceesd

cd mirgecom

git fetch https://github.com/illinois-ceesd/mirgecom.git y1_production:y1_production
git checkout master
git branch -D temp || true
git switch -c temp
git merge y1_production


echo RUNNING
rm -Rf CEESD-Y1_nozzle
git clone https://github.com/anderson2981/CEESD-Y1_nozzle.git

cat <<EOF > add-timing.patch
diff --git a/startup/nozzle.py b/startup/nozzle.py
index b8a3fd5..5e0f006 100644
--- a/startup/nozzle.py
+++ b/startup/nozzle.py
@@ -397,19 +397,27 @@ def main(ctx_factory=cl.create_some_context,
                               constant_cfl=constant_cfl, comm=comm, vis_timer=vis_timer,
                               overwrite=True,s0=s0_sc,kappa=kappa_sc)

+    from time import time
+    start = time()
     if rank == 0:
         logging.info("Stepping.")

-    (current_step, current_t, current_state) = \
-        advance_state(rhs=my_rhs, timestepper=timestepper,
-                      checkpoint=my_checkpoint,
-                      get_timestep=get_timestep, state=current_state,
-                      t_final=t_final, t=current_t, istep=current_step,
-                      logmgr=logmgr,eos=eos,dim=dim)
+    my_rhs(t, state)
+
+    #(current_step, current_t, current_state) = \
+    #    advance_state(rhs=my_rhs, timestepper=timestepper,
+    #                  checkpoint=my_checkpoint,+    #                  get_timestep=get_timestep, state=current_state,
+    #                  t_final=t_final, t=current_t, istep=current_step,
+    #                  logmgr=logmgr,eos=eos,dim=dim)

     if rank == 0:
         logger.info("Checkpointing final state ...")

+    elapsed = time()
+    with open("case-time.txt", "w") as outf:
+        outf.write(f"{repr(time())} {repr(elapsed)}\n")
+
     my_checkpoint(current_step, t=current_t,
                   dt=(current_t - checkpoint_t),
                   state=current_state)
EOF

(cd CEESD-Y1_nozzle; patch -p1 < ../add-timing.patch)

cd CEESD-Y1_nozzle/startup
PYOPENCL_TEST=port:pthread python -m mpi4py nozzle.py

eval $(ssh-agent)
trap "kill $SSH_AGENT_PID" EXIT

# requires SSH private key in file timing-key
# requires corresponding public key in
# https://github.com/illinois-ceesd/timing/settings/keys/new
ssh-add timing-key.pub

git clone git@github.com:illinois-ceesd/timing.git

cat timing/y1-nozzle-timings.txt >> CEESD-Y1_nozzle/startup/case-time.txt
(cd timing && git commit -m "Automatic commit $(date)" && git push)
