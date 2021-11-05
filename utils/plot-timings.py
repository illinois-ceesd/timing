#!/usr/bin/env python3
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
import argparse
import yaml
from matplotlib.dates import date2num
import matplotlib.pyplot as plt


def parse_datetime(s):
    # I really don't know why we decided to not save Unix timestamps
    import datetime
    if isinstance(s, datetime.datetime):
        return s
    if isinstance(s, datetime.date):
        return datetime.datetime.combine(s, datetime.datetime.min.time())
    return datetime.datetime.strptime(s, "%Y-%m-%d %H:%M")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--per-step", action="store_true")
    parser.add_argument("-l", "--log-scale", action="store_true")
    parser.add_argument("-z", "--zero", action="store_true")
    parser.add_argument("-d", "--date", metavar="YYYY-MM-DD")
    parser.add_argument("datafile", metavar="DATA.yaml")
    parser.add_argument("--save-plot", metavar="NAME.{pdf,png}")
    args = parser.parse_args()

    # Grab the data from the YAML timing file
    yaml_data = yaml.load_all(open(args.datafile), Loader=yaml.FullLoader)
    raw_data = [d for d in yaml_data if d is not None]  # Remove yaml's trailing None
    data = []
    for d in raw_data:
        d["run_date"] = parse_datetime(d["run_date"])
        if args.date:
            start_date = date2num(parse_datetime(args.date+" 00:00"))
            run_date = date2num(d["run_date"])
            if run_date < start_date:
                continue
        data.append(d)

    kwargs = {
        "marker": "o",
        "ms": 5,
        "markerfacecolor": "w",
        "linestyle": "-",
        "linewidth": 2,
    }
    colors = ['tab:blue', 'tab:orange', 'tab:green']
    leg = []

    timing_names =  ["time_startup", "time_first_step", "time_second_10"]
    timing_labels = ["startup", "first timestep", "second 9 timesteps"]
    scalfac = 1.0
    figwidth=10
    figheight=8
    if args.per_step:
        timing_names =  timing_names[-1:]
        timing_labels = ["second 9 timesteps, per time step"]
        scalfac = 1.0/9.0
        figheight=4

    numplots = len(timing_names)

    # Plot the data
    fig, ax = plt.subplots(ncols=1, nrows=numplots, sharex=True, figsize=(figwidth, figheight), constrained_layout=True)

    if numplots == 1:
        ax = [ax]

    # clean data
    for s in timing_names:
        data = [d for d in data if s in d]

    for i, s in enumerate(timing_names):
        p, = ax[i].plot([d["run_date"] for d in data],
                        [scalfac*d[s] for d in data],
                        label=timing_labels[i], color=colors[i], **kwargs)
        if args.zero:
            ylim = ax[i].get_ylim()
            plt.ylim(0, 1.5*ylim[1])

        if args.log_scale:
            ax[i].set_yscale('log', base=2)
        leg.append(p)

    commentcounter = 0
    commentcolors = ['tab:cyan', 'tab:pink', 'tab:cyan', 'tab:pink']
    for d in data:
        if "comment" in d:
            commentcounter += 1
            ytext0 = 1.2
            ytextdelta = 0.1
            ytext = ytext0 + (commentcounter % 4) * ytextdelta
            # color = commentcolors[commentcounter % 4]
            color = 'tab:gray'
            for i in range(numplots):
                xlim = ax[0].get_xlim()
                xt = (date2num(d['run_date'])-xlim[0]) / (xlim[1]-xlim[0])
                #(xt, _) = ax[0].transLimits.transform((date2num(d['run_date']),0))  # get the coordinates on the axis
                ax[i].plot([xt, xt], [-0.05, ytext-0.05], transform=ax[i].transAxes,
                           color=color, linestyle='--', lw=1, clip_on=False)
                if i==0:
                    ax[i].text(xt, ytext, d['comment'], ha='center', transform=ax[i].transAxes,
                               color=color, rotation=90)

    ax[-1].tick_params(axis="x", labelrotation=45, labelsize=12)
    for i in range(numplots):
        ax[i].grid(True)
    ax[-1].set_xlabel("date", fontsize=12)
    ax[0].legend(handles=leg,
              bbox_to_anchor=(0,1.02,0.3,0.2), loc="lower left",
              mode="expand", borderaxespad=0, ncol=1)
    if args.per_step:
        ax[0].set_ylabel("walltime/step (s)", fontsize=12)
    else:
        for i in range(numplots):
            ax[i].set_ylabel("time (s)", fontsize=12)
    if args.save_plot:
        plt.savefig(args.save_plot, bbox_inches="tight")
    else:
        plt.show()

if __name__ == "__main__":
    main()
