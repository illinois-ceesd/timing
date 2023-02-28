#!/usr/bin/env python3

import argparse
import os
import shutil
import yaml
import socket
from jsonschema import validate, exceptions
import datetime
import platform
import sys
import parsl
import hashlib
from pathlib import Path
from git import Repo
from parsl.executors import HighThroughputExecutor
from parsl.providers import LSFProvider
from parsl.launchers import JsrunLauncher
from parsl.providers import SlurmProvider
from parsl.launchers import SrunLauncher

from parsl.data_provider.files import File
from parsl.app.app import bash_app, python_app
from parsl.config import Config

def nodeJoin(loader, nodeid):
    return ''.join([str(item) for item in loader.construct_sequence(nodeid)])

yaml.add_constructor('!join', nodeJoin)

TIMING_DATE = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

print(datetime.datetime.now())

class Runner:
    ITEMS = ['name', 'repo', 'branch', 'execname', 'params', 'pyopenclCTX',
             'execopts', 'timing_env_name', 'yaml_file_name', 'logdir',
             'mem_usage']
    def __init__(self, ymlFile):
        self.timestamp = datetime.datetime.now().strftime("%Y.%m.%d-%H.%M.%S")
        self.batch_output_file = None
        self.fname = None
        self.hash = None
        self.md5sum = None
        self.executor = None
        self.work_dir = None
        self.paramsfile = None
        self.sqlfile = None
        self.mem_usage = False
        for it in Runner.ITEMS:
            setattr(self, it, None)

        if not self.loadYaml(ymlFile):
            raise Exception(f"Could not load test runner {ymlFile}")

    def setMD5(self, msum):
        self.md5sum = msum

    def verify_runner(self, ymlFile):
        self.fname = ymlFile
        if os.path.isfile(ymlFile):
            pass
        elif os.path.isfile(ymlFile + '.yml'):
            self.fname = ymlFile + '.yml'
        elif os.path.isfile(ymlFile + '.yaml'):
            self.fname = ymlFile + '.yaml'
        else:
            self.fname = None

    def get(self, item):
        return getattr(self, item, None)

    def loadYaml(self, ymlFile, vars):
        self.verify_runner(ymlFile)
        if self.fname:
            try:
                validate(yaml.load(self.fname), yaml.load("test_schema.yaml"))
            except exceptions.ValidationError:
                return False
            drv = yaml.load(open(self.fname, 'r'), Loader=yaml.FullLoader)

            for it in Runner.ITEMS:
                setattr(self, it, drv['driver'][it])

            self.batch_output_file = f"{self.summary_file_root}_{self.timestamp}.out"
            self.sqlfile = os.path.join(vars['sql_path'], self.name) + '-rank0.sqlite'
            return True
        return False

    def get_driver(self):
        cwd = os.getcwd()
        os.system(f"rm -rf {self.name}")

        Repo.clone_from(f"https://github.com/{self.repo}", os.path.join(os.getcwd(), self.name),
                        branch=self.branch)
        os.chdir(os.path.join(self.name, "timing_run"))
        self.work_dir = os.getcwd()
        drepo = Repo(os.getcwd())
        self.hash = drepo.rev_parse("HEAD").hexsha
        drepo.close()
        os.chdir(cwd)

    def write_params(self):
        self.paramsfile = os.path.join(self.work_dir, self.name) + "_timing_params.yaml"
        with open(self.paramsfile, 'w') as yfh:
            yaml.dump(self.params, yfh)

    def getExecutor(self, emirge, vars):
        if vars['host'].lower() == 'lassen':
            self.executor = HighThroughputExecutor(label=self.name,
                                                   working_dir=self.work_dir,
                                                   address='lassen.llnl.gov',
                                                   worker_port_range=(5000, 55000),
                                                   worker_debug=True,
                                                   provider=LSFProvider(launcher=JsrunLauncher(overrides=''),
                                                                        walltime='01:00:00',
                                                                        nodes_per_block=vars['nnodes'],
                                                                        init_blocks=vars['nnodes'],
                                                                        max_blocks=vars['nnodes'],
                                                                        bsub_redirection=True,
                                                                        scheduler_options=f"#BSUB -q {vars['queue']}",
                                                                        worker_init=("module load spectrum-mpi\n"
                                                                                     f"source {os.path.join(emirge, 'config', 'activate_env.sh')}\n"
                                                                                     f"export PYOPENCL_CTX=\"{vars['pyopenclCTX']}\"\n"
                                                                                     f"export XDG_CACHE_HOME=\"{os.path.join(os.sep, 'tmp', '$USER', 'xdg-scratch', self.name)}\"\n"
                                                                                     "rm -rf \$XDG_CACHE_HOME\n"
                                                                                     "rm -f timing-run-done\n"
                                                                                     "which python\n"
                                                                                     "conda env list\n"
                                                                                     "env\n"
                                                                                     "env | grep LSB_MCPU_HOSTS\n"
                                                                                     ),
                                                                        project=vars['project'],
                                                                        cmd_timeout=600
                                                                        )
                                                   )

        elif vars['host'].lower() == 'quartz':
            # not completely configured yet
            '''
            self.executor = HighThroughputExecutor(label=self.name,
                                                   working_dir='',
                                                   address='quartz.llnl.gov',
                                                   worker_port_range=(50000, 55000),
                                                   worker_debug=True,
                                                   provider=SlurmProvider(launcher=SrunLauncher(overrides=f''),
                                                                          walltime='02:00:00',
                                                                          nodes_per_block=1,
                                                                          init_blocks=1,
                                                                          max_blocks=1,
                                                                          scheduler_options='#SBATCH -q pdebug',
                                                                          worker_init=("module load spectrum-mpi\n"
                                                                                       f"export XDG_CACHE_HOME=/tmp/$USER/xdg-scratch_{self.name}\n"
                                                                                       "conda activate ...\n"
                                                                                       ),
                                                                          cmd_timeout=600
                                                                          )
                                                   )'''
            raise Exception("Executor for quartz not implemented yet.")
        else:
            raise Exception(f"Could not create Executor for {vars['host']}")


def run(cls, outputs=[]):
    outputs.append(File(cls.sqlfile))
    return f"python -O -u -m mpi4py {os.path.join(cls.work_dir, cls.name + '.py')} -i {cls.paramsfile} {cls.execopts}"

def process(cls, var, inputs=[]):
    import subprocess
    import socket
    import datetime
    import platform

    uname = platform.uname()
    timing_platform = uname.system
    timing_arch = uname.machine

    if not os.path.isfile(inputs[0]):
        return False
    if os.path.isfile(cls.yaml_file_name):
        os.remove(cls.yaml_file_name)
    summary_file_name = os.path.join(var['sql_path'], cls.summary_file_root + '_' + cls.timestamp) + '.sqlite'
    if os.path.isfile(summary_file_name):
        os.remove(summary_file_name)
    # --- Pull the timings out of the sqlite files generated by logging

    rgather = subprocess.Popen(f"runalyzer-gather {summary_file_name} {inputs[0]////////}",
                               stdout=subprocess.PIPE, shell=True, text=True)
    outs, errs = rgather.communicate()
    cld = subprocess.Popen(f"$(sqlite3 {summary_file_name} 'SELECT cl_device_name FROM runs')",
                           stdout=subprocess.PIPE, shell=True, text=True)
    cl_device, errs = cld.communicate()

    stup = subprocess.Popen(f"$(runalyzer -m {summary_file_name} -c 'print(q(\"select $t_init.max\").fetchall()[0][0])' | grep -v INFO)",
                            stdout=subprocess.PIPE, shell=True, text=True)
    startup_time, errs = stup.communicate()

    fst = subprocess.Popen(f"$(runalyzer -m {summary_file_name} -c 'print(sum(p[0] for p in q(\"select $t_step.max\").fetchall()[0:1]))' | grep -v INFO))",
                           stdout=subprocess.PIPE, shell=True, text=True)
    first_step, errs = fst.communicate()

    ften = subprocess.Popen(f"$(runalyzer -m {summary_file_name} -c 'print(sum(p[0] for p in q(\"select $t_step.max\").fetchall()[0:10]))' | grep -v INFO)",
                            stdout=subprocess.PIPE, shell=True, text=True)
    first_10_steps, errs = ften.communicate()

    sten = subprocess.Popen(f"$(runalyzer -m {summary_file_name} -c 'print(sum(p[0] for p in q(\"select $t_step.max\").fetchall()[10:19]))' | grep -v INFO)",
                            stdout=subprocess.PIPE, shell=True, text=True)
    second_10_steps = sten.communicate()

    output = {'run_date': TIMING_DATE,
              'run_host': socket.gethostname(),
              'cl_device': cl_device,
              'run_epoch': datetime.datetime.now().timestamp(),
              'run_platform': timing_platform,
              'run_arch': timing_arch,
              'gpu_arch': vars['gpu_arch'],
              'mirge_version': vars['mirge_hash'],
              'y1_version': vars['mirge_hash'],
              'driver_version': cls.hash,
              'driver_md5sum': cls.md5sum,
              'time_startup': startup_time,
              'time_first_step': first_step,
              'time_first_10': first_10_steps,
              'time_second_10': second_10_steps}

    if cls.mem_usage:
        mpmu = subprocess.Popen(f"$(runalyzer -m {summary_file_name} -c 'print(max(p[0] for p in q(\"select $memory_usage_python.max\").fetchall()))' | grep -v INFO)",
                                stdout=subprocess.PIPE, shell=True, text=True)
        max_python_mem_usage, err = mpmu.communicate()

        mgmu = subprocess.Popen(f"$(runalyzer -m {summary_file_name} -c 'print(max(p[0] for p in q(\"select $memory_usage_gpu.max\").fetchall()))' | grep -v INFO)",
                                stdout=subprocess.PIPE, shell=True, text=True)
        max_gpu_mem_usage, err = mgmu.communicate()

        output['max_python_mem_usage'] = max_python_mem_usage
        output['max_gpu_mem_usage'] = max_gpu_mem_usage


    yaml.dump(output, open(cls.yaml_file_name, 'w'))
    return True

def setup_env(args):
    cwd = os.getcwd()
    # -- Install conda env, dependencies and MIRGE-Com via *emirge*
    # --- remove old run if it exists
    if os.path.isdir("emirge"):
        shutil.move("emirge", "emirge.old")
        os.system("rm -rf emirge.old &")

    # --- grab emirge and install MIRGE-Com
    Repo.clone_from("https://github.com/illinois-ceesd/emirge.git",
                    os.path.join(cwd, "emirge"))
    os.chdir("emirge")
    os.system(f"./install.sh --branch=${args.mirge_branch} --env-name=timing_tests")
    os.chdir("mirgecom")
    mrepo = Repo(os.getcwd())
    # -- Grab and merge the branch with the case-dependent features
    mhash = mrepo.rev_parse(f"origin/{args.mirge_branch}").hexsha
    mrepo.close()
    os.chdir(cwd)
    return mhash


def parse_args():
    parser = argparse.ArgumentParser(description="Mirgecom timing tests")
    parser.add_argument("-r", "--run", type=ascii, dest="runners",
                        action="store", nargs="?",
                        help="The tests to run (must match yaml file name)")
    parser.add_argument("-m", "--build_mirgecom", actio='store_true',
                        dest="buld_mirecom", help="Whether to build mirgecom")
    parser.add_argument("-b", "--mirge_branch", type=ascii, action='store', dest="mirge_branch",
                        default="production", help="The branch of emirge to build, Default is production")
    parser.add_argument("-y", "--yml", action='store', default='testing.yaml')
    parser.add_argument()
    return parser.parse_args()

if __name__ == '__main__':
    timing_home = os.getcwd()
    emirge_home = os.path.join(timing_home, 'emirge')

    cmdargs = parse_args()
    master_vars = yaml.load(cmdargs.yml, Loader=yaml.FullLoader)

    runners = []
    for yml in cmdargs.runners:
        runners.append(Runner(yml))
    master_vars['mirge_hash'] = setup_env(cmdargs)
    executors = []
    run_jobs = []
    process_jobs = []
    for runner in runners:

        runner.get_driver()
        # --- Get an MD5Sum for the untracked timing driver

        md5_hash = hashlib.md5()
        with open(runner.get('execname') + '.py', 'rb') as fh:
            for block in iter(lambda: fh.read(4096), b""):
                md5_hash.update(block)
        runner.setMD5(md5_hash.hexdigest())
        runner.getExecutor(emirge_home, master_vars)
        runner.write_params()
        executors.append(runner.executor)
    parsl.set_stream_logger()
    parsl.clear()
    parsl.load(Config(executors=executors))
    for runner in runners:
        crunner = (bash_app(executors=[runner.name]))(run)(runner)
        run_jobs.append(crunner)
        process_jobs.append((python_app(executors=[runner.name])))(run)(runner, master_vars, inputs=crunner.outputs[0])

    # -- Run the case (platform-dependent)
    #printf "Running on Host: ${TIMING_HOST}\n"
    # Users should set special keys for using git over
    # ssh for security concerns. This snippet will use
    # a pre-arranged ssh key if the user provides one
    # and indicates it with the TESTING_SSH_KEY environment
    # variable.
    # ===== To create a key:
    # - Run ssh-keygen:
    # $ ssh-keygen
    # [enter a <keyname> when prompted]
    # - Put the key(s) in a /secure/filesystem/location:
    # $ mv <keyname>* /secure/filesystem/location
    # - Add the key to GIT:
    # $ [browse to] https://github.com/illinois-ceesd/timing/settings/keys/new
    # $ Choose (New SSH key)
    # $ Paste in the contents of /secure/filesystem/location/<keyname>.pub
    # - Set the ENV variable before using this script:
    # $ export TESTING_SSH_KEY=/secure/filesystem/location/<keyname>
    if 'TESTING_SSH_KEY' in os.environ:
        ssh_job = subprocess.Popen("eval $(ssh-agent); trap \"kill $SSH_AGENT_PID\" EXIT; ssh-add ${TESTING_SSH_KEY}",
                                   stdout=subprocess.PIPE, shell=True, text=True)

    # --- Update the timing data in the repo
    # ---- First, clone the timing repo
    Repo.clone_from(f"git@github.com:{master_vars['timing_repo']}", os.path.join(os.getcwd(), 'timing'),
                    branch=master_vars['timing_branch'])
    timing_repo = Repo(os.path.join(os.getcwd(), 'timing'))
    # ---- Create the timing file if it does not exist
    count = 0
    for runner, i in enumerate(runners):
        if not process_job.result():
            print(f"Timing run did not produce the expected sqlite file: {runner.sqlfile}\n")
            continue
        count += 1
        if not os.path.exists(os.path.join("timing", runner.yaml_file_name))
            Path(os.path.join(os.getcwd(), 'timing', runner.yaml_file_name)).touch()
            timing_repo.index.add([os.path.join("timing", runner.yaml_file_name)])

        # ---- Update the timing file with the current test data

        os.system(f"cat {runner.yaml_file_name} >> timing/{runner.yaml_file_name}")
        os.makedirs(os.path.join('timin', runner.logdir), exist_ok=True)
        summary_file_name = os.path.join(master_vars['sql_path'], runner.summary_file_root + '_' + runner.timestamp) + '.sqlite'
        shutil.copy(summary_file_name, os.path.join("timing", runner.logdir))
        os.system(f"cat *.out > timing/{runner.logdir}/{runner.batch_output_file}")
        timing_repo.index.add([os.path.join('timing', runner.logdir])
    # ---- Commit the new data to the repo
    if count > 0
        commit = timing_repo.indexs.commit(f"Automatic commit: {socket.gethostname()} {TIMING_DATE}")
        timing_repo.remotes.origin.push()
