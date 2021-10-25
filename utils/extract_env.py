def get_section_string(source, section_start):
    first_line_end = source.find("\n", section_start)
    next_section_start = source.find("\n***", section_start)
    return source[first_line_end+1:next_section_start]


with open("output.txt", "r") as text_file:
    env_dump = text_file.read()
env_dump = env_dump[2:-2]  # takes out some begin/end junk
env_dump = env_dump.replace("\\n", "\n")  # unparse the newlines

pip_starts = env_dump.find("*** Pip")
conda_info_starts = env_dump.find("*** Conda info")
conda_env_starts = env_dump.find("*** Conda env")
os_starts = env_dump.find("*** OS")
req_starts = env_dump.find("*** Requirements")

pip_string = get_section_string(env_dump, section_start=pip_starts)
conda_info_string = get_section_string(env_dump, section_start=conda_info_starts)
conda_env_string = get_section_string(env_dump, section_start=conda_env_starts)
os_string = get_section_string(env_dump, section_start=os_starts)
req_string = get_section_string(env_dump, section_start=req_starts)
clip_start = conda_env_string.find("\nprefix")
conda_env_string = conda_env_string[0:clip_start+1]

with open("requirements.txt", "w") as text_file:
    text_file.write(req_string)
with open("conda.yml", "w") as text_file:
    text_file.write(conda_env_string)
