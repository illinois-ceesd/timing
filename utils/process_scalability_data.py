import sys
import os
import pickle
import subprocess
import glob
import matplotlib.pyplot as plt

import numpy as np

def plot_startup_time(data):
    # Extract required data
    nprocs = sorted(list(data.keys()))
    startup_times = [float(data[nproc]['STARTUP_TIME']) for nproc in nprocs]
    
    # Components of startup time
    components = {
        'MeshRead': 'GET_MESH',
        'MeshPart': 'MESH_PART',
        'MeshSplit': 'MESH_SPLIT',
        'MeshDist': 'MESH_DIST',
        'SolnInit': 'SOLN_INIT',
        'RestartWrite': 'RST_WRITE'
    }
    
    component_data = {comp: [float(data[nproc][comp_db]) for nproc in nprocs] for comp, comp_db in components.items()}
    
    # Start plotting
    fig, ax = plt.subplots()
    
    # Bar widths scaled by nproc
    bar_widths = [0.7 * nproc for nproc in nprocs]
    
    # Bottom tracker for stacked bar
    bottoms = [0] * len(nprocs)
    
    for comp, values in component_data.items():
        ax.bar(nprocs, values, width=bar_widths, label=comp, bottom=bottoms)
        bottoms = [i + j for i, j in zip(bottoms, values)]
    
    # Settings and labels
    ax.set_xlabel('Number of Processors (Nprocs)')
    ax.set_ylabel('Time (s)')
    ax.set_title('Startup Time Breakdown vs Nprocs')
    ax.set_xscale('log', base=2)
    ax.set_xticks(nprocs)
    ax.get_xaxis().set_major_formatter(plt.ScalarFormatter())
    ax.legend()
    
    # Save to PDF
    plt.tight_layout()
    plt.savefig("startup_time_breakdown.pdf")

# Assuming data is already loaded from the pickle
# plot_startup_time(loaded_data)  # Uncomment to actually plot when you run it


def gather_and_extract_data_v8(directory_path):
    # Navigate to the specified directory
    og_d = os.getcwd()
    os.chdir(directory_path)
    
    # Detect the available nproc values and their corresponding <case_name> and <timestamp>
    file_patterns = glob.glob('*_np*-rank*-*.sqlite')
    nproc_info = {}

    for pattern in file_patterns:
        # Extract nproc
        nproc = int(pattern.split('_np')[1].split('-rank')[0])

        # Extract case_name
        case_name = pattern.split('_np')[0]

        # Extract timestamp
        timestamp = pattern.split('.')[-2].split('-')[-2] + '-' + pattern.split('.')[-2].split('-')[-1]
        
        nproc_info[nproc] = (case_name, timestamp)
    
    # Placeholder for the resulting data
    combined_data = {}
    
    for nproc, (case_name, timestamp) in nproc_info.items():
        print(f"Processing nproc: {nproc}, case_name: {case_name}, time_stamp: {timestamp}")

        # Gather the data for the detected nproc value
        files_to_gather = glob.glob(os.path.join(directory_path, f'{case_name}_np{nproc}-rank*-{timestamp}.sqlite'))
        gathered_file_name = f'{case_name}.np{nproc}.{timestamp}.sqlite'
        if os.path.exists(gathered_file_name):
            os.remove(gathered_file_name)
        cmd = ['runalyzer-gather', gathered_file_name] + files_to_gather
        # print(f"Running: {cmd}")
        subprocess.run(cmd)
        
        # Check if the gathered file is created, if not, skip extraction for this nproc
        if not os.path.exists(gathered_file_name):
            print(f"Warning: Gathered file {gathered_file_name} not found. Skipping data extraction for nproc {nproc}.")
            continue
        
        # Extract data using the provided runalyzer commands and store in a structured format
        data_for_file = {}
        data_for_file["TIMESTAMP"] = timestamp
        data_for_file["NPROC"] = nproc
        data_for_file['CL_DEVICE'] = subprocess.check_output(['sqlite3', gathered_file_name, 'SELECT cl_device_name FROM runs']).decode('utf-8').strip()
        data_for_file['GET_MESH'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(q("select $t_mesh_data.max").fetchall()[0][0])']).decode('utf-8').strip()
        data_for_file['MESH_PART'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(q("select $t_mesh_part.max").fetchall()[0][0])']).decode('utf-8').strip()
        data_for_file['MESH_SPLIT'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(q("select $t_mesh_split.max").fetchall()[0][0])']).decode('utf-8').strip()
        data_for_file['MESH_DIST'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(q("select $t_mesh_dist.max").fetchall()[0][0])']).decode('utf-8').strip()
        data_for_file['SOLN_INIT'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(q("select $t_soln_init.max").fetchall()[0][0])']).decode('utf-8').strip()
        data_for_file['STARTUP_TIME'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(q("select $t_init.max").fetchall()[0][0])']).decode('utf-8').strip()
        data_for_file['RST_WRITE'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(q("select $t_rst_write.max").fetchall()[0][0])']).decode('utf-8').strip()
        data_for_file['FIRST_STEP'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[0:1]))']).decode('utf-8').strip()
        data_for_file['FIRST_10_STEPS'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[0:10]))']).decode('utf-8').strip()
        data_for_file['SECOND_10_STEPS'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(sum(p[0] for p in q("select $t_step.max").fetchall()[10:19]))']).decode('utf-8').strip()
        data_for_file['MAX_PYTHON_MEM_USAGE'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(max(p[0] for p in q("select $memory_usage_python.max").fetchall()))']).decode('utf-8').strip()
        data_for_file['MAX_GPU_MEM_USAGE'] = subprocess.check_output(['runalyzer', gathered_file_name, '-c', 'print(max(p[0] for p in q("select $memory_usage_gpu.max").fetchall()))']).decode('utf-8').strip()
        data_for_file['TIMING_ARCH'] = subprocess.check_output(['uname', '-m']).decode('utf-8').strip()
        
        combined_data[nproc] = data_for_file

    os.chdir(og_d)
    return combined_data

# Placeholder output for visualization
# Please note: You should call this function with the appropriate directory path to execute it.
# combined_data_result_v8 = gather_and_extract_data_v7("/path/to/directory")

# Example on how to save the returned structured data to a file
# with open('combined_data.pkl', 'wb') as file:
#     pickle.dump(combined_data_result_v8, file)

# Example on how to load the structured data from the saved file
# with open('combined_data.pkl', 'rb') as file:
#     loaded_data = pickle.load(file)


# ... [Include the gather_and_extract_data_v8 function definition here]

if __name__ == "__main__":
    # Check if a directory path is provided
    target_path = "./"
    if len(sys.argv) > 1:
        target_path = sys.argv[1]

    # Gather and extract data
    if os.path.isdir(target_path):
        data = gather_and_extract_data_v8(target_path)
        # Save the data to the .pkl file
        max_nproc = max(data.keys())
        timestamps = [info["TIMESTAMP"] for info in data.values()]
        max_timestamp = max(timestamps)
        pkl_filename = f"scal_np{max_nproc}_{max_timestamp}.pkl"
        if os.path.exists(pkl_filename):
            os.remove(pkl_filename)
        with open(pkl_filename, 'wb') as file:
            pickle.dump(data, file)
    else:
        with open(target_path, 'rb') as file:
            data = pickle.load(file)

    plot_startup_time(data)

