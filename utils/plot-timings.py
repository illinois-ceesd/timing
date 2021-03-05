"""Plot MIRGE-Com timing results."""

__copyright__ = """
Copyright (C) 2020 University of Illinois Board of Trustees
"""

__license__ = """
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""
import yaml
import pandas as pd
import matplotlib.pyplot as plt

# Grab the data from the YAML timing file
data = yaml.load_all(open('y1-nozzle-timings.yaml', 'r'), Loader=yaml.FullLoader)
data = [d for d in list(data) if d is not None]  # Remove yaml's trailing None
df = pd.DataFrame(data)
df['run_date'] = pd.to_datetime(df['run_date'], errors='coerce')

# Plot the data
fig, ax = plt.subplots(figsize=(10,5))
kwargs = {'marker': 'o',
          'ms': 5,
          'markerfacecolor': 'w',
          'linestyle': '-',
          'linewidth': 2,
         }

for s in ['time_startup', 'time_first_step', 'time_second_10']:
    ax.plot(df['run_date'], df[s], label=s.replace('time_',''), **kwargs)

ax.tick_params(axis='x', labelrotation = 45, labelsize=16)
ax.grid(True)
ax.set_xlabel('date', fontsize=20)
ax.set_ylabel('time (s)', fontsize=20)
ax.legend(fontsize=18)
plt.savefig('y1-nozzle-timings.png', bbox_inches='tight')
plt.show()
