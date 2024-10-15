#!/usr/bin/env python3

import argparse
import os
import shutil
import yaml
from jsonschema import validate, exceptions
import subprocess
import datetime
import parsl
import hashlib
import socket
from pathlib import Path
from git import Repo
from parsl.executors import HighThroughputExecutor
from parsl.providers import LSFProvider
from parsl.launchers import JsrunLauncher
from parsl.data_provider.files import File

# quartz imports
# from parsl.providers import SlurmProvider
# from parsl.launchers import SrunLauncher

from parsl.app.app import bash_app, python_app
from parsl.config import Config


def nodeJoin(loader, nodeid):
    """ Helper function to handle the !join keyword in yaml documents

        Parameters
        ----------
        loader: yaml.Loader instance
        nodeid: the name of the node to operate on

        Example
        -------
        yaml document as follows:

        exec: &EXEC isolator
        log: !join [ *EXEC, .log ]

        will produce
        {
        "exec": "isolator",
        "log": "isolator.log"
        }

        when loaded
    """
    return ''.join([str(item) for item in loader.construct_sequence(nodeid)])


# add the nodeJoin function to the yal Loader
yaml.add_constructor('!join', nodeJoin)


print(datetime.datetime.now())

# schema for the main testing yaml
TIMING_SCHEMA = {"title": "Timing Global Schema",
                 "description": "Schema for main timing test process",
                 "type": "object",
                 "properties": {
                     "timing": {
                         "$ref": "#/definitions/Timing"
                         }
                     },
                 "required": ["timing"],
                 "definitions": {
                     "Timing": {
                         "type": "object",
                         "properties": {
                             "sql_path": {"type": "string"},
                             "project": {"type": "string"},
                             "queue": {"type": "string"},
                             "nnodes": {"type": "number", "minimum": 1},
                             "mirge_branch": {"type": "string"},
                             "pyopenclCTX": {"type": "string"},
                             "host": {"type": "string"},
                             "gpu_arch": {"type": "string"},
                             "timing_repo": {"type": "string"},
                             "timing_branch": {"type": "string"}
                             },
                         "required": ["sql_path", "project", "queue", "nnodes", "mirge_branch", "pyopenclCTX",
                                      "host", "gpu_arch", "timing_repo", "timing_branch"]
                         }
                     }
                 }

# schema for the driver yamls                                                                                           
DRIVER_SCHEMA = {"title": "Driver Schema",
                 "description": "Schema for testing driver",
                 "type": "object",
                 "properties": {
                     "driver": {
                         "$ref": "#/definitions/Driver"
                         }
                     },
                 "required": ["driver"],
                 "definitions": {
                     "Driver": {
                         "type": "object",
                         "properties": {
                             "name": {"type": "string"},
                             "repo": {"type": "string"},
                             "branch": {"type": "string"},
                             "execname": {"type": "string"},
                             "params": {"type": "object"},
                             "timing_env_name": {"type": "string"},
                             "summary_file_root": {"type": "string"},
                             "yaml_file_name": {"type": "string"},
                             "logdir": {"type": "string"},
                             "execopts": {"type": "string"},
                             "mem_usage": {"type": "boolean"}
                             },
                         "required": ["name", "repo", "branch", "execname", "params", "timing_env_name",
                                      "summary_file_root", "yaml_file_name", "logdir", "execopts"]
                         }
                     }
                 }

class Driver:
    """ Class to define a test instance                                                                                 
                                                                                                                        
        Parameters                                                                                                      
        ----------                                                                                                      
        ymlFile: str, the name of the yaml file giving the parameters for the run                                       
        lazy: bool, whether the test is a lazy test                                                                     
        root_dir: str, the root directory for the tests                                                                 
        test_vars: dict, Listing of the overall testing variables                                                       
    """
    ITEMS = ['name', 'repo', 'branch', 'execname', 'params',
             'execopts', 'timing_env_name', 'yaml_file_name', 'logdir',
             'mem_usage', 'summary_file_root']

    def __init__(self, ymlFile, lazy, root_dir, test_vars):
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
        self.root_dir = root_dir
        self.yamlFile = "test_drivers/time-"
        if lazy:
            self.yamlFile += "lazy-"
        self.yamlFile += ymlFile
        for it in Driver.ITEMS:
            setattr(self, it, None)

        # load the given yaml file                                                                                      
        if not self.loadYaml(test_vars):
            raise Exception(f"Could not load test runner {self.yamlFile}")

    def setMD5(self, msum):
        """ Set the md5 sum"""
        self.md5sum = msum

    def verify_runner(self):
        """ Function to determine the actual name of the yaml file. It tries:                                           
            yamlFile, yamlFile + '.yml', and yamlFile + '.yaml'                                                         
        """
        self.fname = os.path.join(self.root_dir, self.yamlFile)
        if os.path.isfile(self.fname):
            pass
        elif os.path.isfile(self.fname + '.yml'):
            self.fname += '.yml'
        elif os.path.isfile(self.fname + '.yaml'):
            self.fname += '.yaml'
        else:
            raise Exception(f"Cound not find file. {self.fname}")

    def get(self, item):
        """ General getter function"""
        return getattr(self, item, None)

    def loadYaml(self, var):
        """ Function to load the driver yaml file, this includes error checking against                                 
            the schema, and adding the loaded values to the class member variables                                      
                                                                                                                        
            Parameters                                                                                                  
            ----------                                                                                                  
            var: dict, Listing of the overall testing variables                                                         
                                                                                                                        
            Returns                                                                                                     
            -------                                                                                                     
            Bool, True if the yaml was loaded, False otherwise.                                                         
        """
        self.verify_runner()
        if self.fname:
            drv = yaml.load(open(self.fname, 'r'), Loader=yaml.FullLoader)
            validate(drv, DRIVER_SCHEMA)

            for it in Driver.ITEMS:
                setattr(self, it, drv['driver'][it])

            self.batch_output_file = f"{self.summary_file_root}_{self.timestamp}.out"
            self.sqlfile = os.path.join(var['sql_path'], self.execname) + '-rank0.sqlite'
            return True
        return False

    def get_driver(self):
        """ Function to clone the given driver repo                                                                     
        """
        cwd = os.getcwd()
        os.system(f"rm -rf {self.name}")

        Repo.clone_from(f"https://github.com/{self.repo}", os.path.join(os.getcwd(), self.name),
                        branch=self.branch)
        os.chdir(os.path.join(self.name))
        self.work_dir = os.getcwd()
        drepo = Repo(os.getcwd())
        self.hash = drepo.rev_parse("HEAD").hexsha
        drepo.close()
        os.chdir(cwd)

    def write_params(self):
        """ Write the driver parameters to a yaml file for the test to run with                                         
        """
        self.paramsfile = os.path.join(self.work_dir, self.name) + "_timing_params.yaml"
        with open(self.paramsfile, 'w') as yfh:
            yaml.dump(self.params, yfh)

    def getExecutor(self, emirge, var):
        """ Define the Parsl Executor to use with this test.                                                            
                                                                                                                        
            Parameters                                                                                                  
            ----------                                                                                                  
            emirge: str, path to the emirge directory                                                                   
            var: dict, Listing of the overall testing variables                                                         
        """
        if var['host'].lower() == 'lassen':
            return HighThroughputExecutor(label=self.name,
                                          working_dir=self.work_dir,
                                          address='lassen.llnl.gov',
                                          worker_port_range=(5000, 55000),
                                          worker_debug=True,
                                          provider=LSFProvider(launcher=JsrunLauncher(overrides=''),
                                                               walltime='01:00:00',
                                                               nodes_per_block=var['nnodes'],
                                                               init_blocks=var['nnodes'],
                                                               max_blocks=var['nnodes'],
                                                               bsub_redirection=True,
                                                               queue=var['queue'],
                                                               worker_init=("module load spectrum-mpi\n"
                                                                            f"source {os.path.join(emirge, 'miniforge3', 'bin', 'activate')} timing_tests\n"
                                                                            f"export PYOPENCL_CTX=\"{var['pyopenclCTX']}\"\n"
                                                                            f"export XDG_CACHE_HOME=\"{os.path.join(os.sep, 'tmp', '$USER', 'xdg-scratch', self.name)}\"\n"
                                                                            "rm -rf $XDG_CACHE_HOME\n"
                                                                            "rm -f timing-run-done\n"
                                                                            "which python\n"
                                                                            "conda env list\n"
                                                                            f"cd {os.path.join(self.work_dir, 'timing_run')}\n"
                                                                           ),
                                                               project=var['project'],
                                                               cmd_timeout=600
                                                              )
                                                   )

        elif var['host'].lower() == 'quartz':
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
            raise Exception(f"Could not create Executor for {var['host']}")


def run(work_dir, name, paramsfile, execn, execopts, outputs=[]):
    """ Run the test. This function is called through a Parsl bash_app.

        Parameters
        ----------
        cls: Driver instance, defining the test to be run
        outputs: List of Parsl File objects containing the output data from the test
    """
    import os
    return f"python -O -u -m mpi4py {os.path.join(work_dir, 'timing_run', execn + '.py')} -i {paramsfile} {execopts}"


def process(summary_file_root, timestamp, yaml_file_name, hsh, md5sum, var, mem_usage, inputs=[]):
    """ Process the test results. This function is run through a Parsl python_app.

        Parameters
        ----------
        cls: Driver instance, defining the test to be processed
        var: dict, Listing of the overall testing variables
        inputs: List of Parsl File objects containing the outputs from the test run

        Returns
        -------
        Bool, True if the run completed, False otherwise

    """
    import os
    import subprocess
    import socket
    import datetime
    import platform
    import yaml

    TIMING_DATE = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    uname = platform.uname()
    timing_platform = uname.system
    timing_arch = uname.machine

    if not os.path.isfile(inputs[0]):
        return False
    if os.path.isfile(yaml_file_name):
        os.remove(yaml_file_name)
    s_file_name = os.path.join(var['sql_path'], summary_file_root + '_' + timestamp) + '.sqlite'
    if os.path.isfile(s_file_name):
        os.remove(s_file_name)
    # --- Pull the timings out of the sqlite files generated by logging

    rgather = subprocess.Popen(f"runalyzer-gather {s_file_name} {inputs[0]}",
                               stdout=subprocess.PIPE, shell=True, text=True)
    outs, errs = rgather.communicate()
    cld = subprocess.Popen(f"$(sqlite3 {s_file_name} 'SELECT cl_device_name FROM runs')",
                           stdout=subprocess.PIPE, shell=True, text=True)
    cl_device, errs = cld.communicate()

    stup = subprocess.Popen(f"$(runalyzer -m {s_file_name} -c 'print(q(\"select $t_init.max\").fetchall()[0][0])' | grep -v INFO)",
                            stdout=subprocess.PIPE, shell=True, text=True)
    startup_time, errs = stup.communicate()

    fst = subprocess.Popen(f"$(runalyzer -m {s_file_name} -c 'print(sum(p[0] for p in q(\"select $t_step.max\").fetchall()[0:1]))' | grep -v INFO))",
                           stdout=subprocess.PIPE, shell=True, text=True)
    first_step, errs = fst.communicate()

    ften = subprocess.Popen(f"$(runalyzer -m {s_file_name} -c 'print(sum(p[0] for p in q(\"select $t_step.max\").fetchall()[0:10]))' | grep -v INFO)",
                            stdout=subprocess.PIPE, shell=True, text=True)
    first_10_steps, errs = ften.communicate()

    sten = subprocess.Popen(f"$(runalyzer -m {s_file_name} -c 'print(sum(p[0] for p in q(\"select $t_step.max\").fetchall()[10:19]))' | grep -v INFO)",
                            stdout=subprocess.PIPE, shell=True, text=True)
    second_10_steps = sten.communicate()

    output = {'run_date': TIMING_DATE,
              'run_host': socket.gethostname(),
              'cl_device': cl_device,
              'run_epoch': datetime.datetime.now().timestamp(),
              'run_platform': timing_platform,
              'run_arch': timing_arch,
              'gpu_arch': var['gpu_arch'],
              'mirge_version': var['mirge_hash'],
              'y1_version': var['mirge_hash'],
              'driver_version': hsh,
              'driver_md5sum': md5sum,
              'time_startup': startup_time,
              'time_first_step': first_step,
              'time_first_10': first_10_steps,
              'time_second_10': second_10_steps}

    if mem_usage:
        mpmu = subprocess.Popen(f"$(runalyzer -m {s_file_name} -c 'print(max(p[0] for p in q(\"select $memory_usage_python.max\").fetchall()))' | grep -v INFO)",
                                stdout=subprocess.PIPE, shell=True, text=True)
        max_python_mem_usage, err = mpmu.communicate()

        mgmu = subprocess.Popen(f"$(runalyzer -m {s_file_name} -c 'print(max(p[0] for p in q(\"select $memory_usage_gpu.max\").fetchall()))' | grep -v INFO)",
                                stdout=subprocess.PIPE, shell=True, text=True)
        max_gpu_mem_usage, err = mgmu.communicate()

        output['max_python_mem_usage'] = max_python_mem_usage
        output['max_gpu_mem_usage'] = max_gpu_mem_usage

    yaml.dump(output, open(yaml_file_name, 'w'))
    return True


def setup_env(args):
    """ Set up the global test environment, including cloning the emirge repo and building it.

        Parameters
        ----------
        args: command line arguments

    """
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
    os.system(f"./install.sh --branch={args.mirge_branch} --env-name=timing_tests")
    os.chdir("mirgecom")
    mrepo = Repo(os.getcwd())
    # -- Grab and merge the branch with the case-dependent features
    mhash = mrepo.rev_parse(f"origin/{args.mirge_branch}").hexsha
    mrepo.close()
    os.chdir(cwd)
    return mhash


def parse_args():
    """ Parse command line arguments """
    parser = argparse.ArgumentParser(description="Mirgecom timing tests")
    parser.add_argument("-r", "--run", dest="runners", action="store",
                        help="The tests to run (must match yaml file name)")
    parser.add_argument("-m", "--build_mirgecom", action='store_true',
                        dest="buld_mirecom", help="Whether to build mirgecom")
    parser.add_argument("-b", "--mirge_branch", action='store', dest="mirge_branch",
                        default="production", help="The branch of emirge to build, Default is production")
    parser.add_argument("-y", "--yml", action='store', default='testing.yaml')
    parser.add_argument("-l", "--lazy", action='store_true', dest="lazy", help="Run lazy computations")
    return parser.parse_args()


if __name__ == '__main__':
    timing_home = os.path.realpath(os.path.dirname(__file__))
    emirge_home = os.path.join(timing_home, 'emirge')

    cmdargs = parse_args()
    cmdargs.runners = cmdargs.runners.replace("'", "").strip().split(',')
    print(cmdargs.runners)
    master_vars = yaml.load(open(os.path.join('test_drivers', cmdargs.yml), 'r'), Loader=yaml.FullLoader)
    validate(master_vars, TIMING_SCHEMA)
    master_vars = master_vars['timing']
    runners = []
    executors = []
    for yml in cmdargs.runners:
        print(yml)
        drv = (Driver(yml, cmdargs.lazy, timing_home, master_vars))
        drv.get_driver()
        md5_hash = hashlib.md5()
        with open(os.path.join(drv.work_dir, 'timing_run', drv.get('execname')) + '.py', 'rb') as fh:
            for block in iter(lambda: fh.read(4096), b""):
                md5_hash.update(block)
        drv.setMD5(md5_hash.hexdigest())
        executors.append(drv.getExecutor(emirge_home, master_vars))
        drv.write_params()
        runners.append(drv)

    master_vars['mirge_hash'] = setup_env(cmdargs)
    run_jobs = []
    process_jobs = []
    #for runner in runners:

    # --- Get an MD5Sum for the untracked timing driver
    parsl.set_stream_logger()
    parsl.clear()
    parsl.load(Config(executors=executors))
    for runner in runners:
        print("RUNNER")
        print(os.path.join(os.getcwd(), runner.sqlfile))
        crunner = bash_app(executors=[runner.name])(run)(runner.work_dir, runner.name, runner.paramsfile, runner.execname, runner.execopts, outputs=[File(os.path.join(runner.work_dir, 'timing_run', runner.sqlfile))])
        run_jobs.append(crunner)

        process_jobs.append(python_app(executors=[runner.name])(process)(runner.summary_file_root, runner.timestamp, runner.yaml_file_name, runner.hash, runner.md5sum, master_vars, runner.mem_usage, inputs=[crunner.outputs[0]]))

    for job in run_jobs:
        print(f"JOB STATUS {job.result()}")
    print(len(process_jobs))
    print("JOBS DONE")

    if 'TESTING_SSH_KEY' in os.environ:
        ssh_job = subprocess.Popen("eval $(ssh-agent); trap \"kill $SSH_AGENT_PID\" EXIT; ssh-add ${TESTING_SSH_KEY}",
                                   stdout=subprocess.PIPE, shell=True, text=True)

    # --- Update the timing data in the repo
    # ---- First, clone the timing repo
    #Repo.clone_from(f"git@github.com:{master_vars['timing_repo']}", os.path.join(os.getcwd(), 'timing'),
    #                branch=master_vars['timing_branch'])
    timing_repo = Repo(os.getcwd())
    # ---- Create the timing file if it does not exist
    count = 0
    for i, runner in enumerate(runners):
        if not process_jobs[i].result():
            print(f"Timing run did not produce the expected sqlite file: {runner.sqlfile}\n")
            continue
        count += 1
        if not os.path.exists(runner.yaml_file_name):
            Path(os.path.join(os.getcwd(), runner.yaml_file_name)).touch()
            timing_repo.index.add([runner.yaml_file_name])

        # ---- Update the timing file with the current test data

        #os.system(f"cat {runner.yaml_file_name} >> timing/{runner.yaml_file_name}")
        #os.makedirs(runner.logdir, exist_ok=True)
        summary_file_name = os.path.join('flame1d-lazy', 'timing_run', master_vars['sql_path'], runner.summary_file_root + '_' + runner.timestamp) + '.sqlite'
        shutil.copy(summary_file_name, runner.logdir)
        os.system(f"cat *.out > timing/{runner.logdir}/{runner.batch_output_file}")
        timing_repo.index.add([os.path.join(runner.logdir, runner.summary_file_root + '_' + runner.timestamp + '.sqlite')])

# ---- Commit the new data to the repo
if count > 0:
    commit = timing_repo.indexs.commit(f"Automatic commit: {socket.gethostname()} {TIMING_DATE}")
    timing_repo.remotes.origin.push()
