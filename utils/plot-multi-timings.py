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
import os

fontsize = 10
params = {  # "backend": "pdf",
          "text.usetex": True,
          "font.family": "serif",
          "font.serif": "Computer Modern Roman",
          # font sizes
          "axes.labelsize": fontsize,
          "font.size": fontsize,
          "axes.titlesize": fontsize,
          "legend.fontsize": fontsize,
          "xtick.labelsize": fontsize,
          "ytick.labelsize": fontsize}

plt.rcParams.update(params)


def parse_datetime(s):
    """Parse the date and time."""
    # I really don't know why we decided to not save Unix timestamps
    import datetime
    if isinstance(s, datetime.datetime):
        return s
    if isinstance(s, datetime.date):
        return datetime.datetime.combine(s, datetime.datetime.min.time())
    return datetime.datetime.strptime(s, "%Y-%m-%d %H:%M")


def main():
    """Plot the timings with this main function. Totally useful docstring."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-m", "--memory", action="store_true")
    parser.add_argument("-s", "--per-step", action="store_true")
    parser.add_argument("-l", "--log-scale", action="store_true")
    parser.add_argument("-z", "--zero", action="store_true")
    parser.add_argument("-c", "--multicase", action="store_true")
    parser.add_argument("-a", "--annotate", action="store_true",
                        help="annotate the figure using comments in the data file")
    parser.add_argument("-d", "--date", metavar="YYYY-MM-DD")
    parser.add_argument("-e", "--end", metavar="YYYY-MM-DD")
    # parser.add_argument("datafile", metavar="DATA.yaml")
    parser.add_argument("files", metavar="file", type=str, nargs="+",
                        help="YAML file(s) to plot.")
    parser.add_argument("--save-plot", metavar="NAME.{pdf,png}")
    args = parser.parse_args()

    markers = ["o", "s", "v", "^", ">", "<", "D", "P", "*", "X"]
    colors = ["tab:blue", "tab:green", "tab:orange", "tab:red",
              "tab:cyan", "m", "y", "k"]

    timing_names = ["time_startup", "time_first_step", "time_second_10"]
    timing_labels = ["startup", "first timestep", "second 9 timesteps"]
    subplot_titles = ["Startup", "First timestep", "Second 9 Timesteps"]
    if args.memory:
        mem_names = ["max_python_mem_usage", "max_gpu_mem_usage"]
        mem_labels = ["host memory (MB)", "device memory (MB)"]
        mem_plot_titles = ["Host Memory", "Device Memory"]
        timing_names.extend(mem_names)
        timing_labels.extend(mem_labels)
        subplot_titles.extend(mem_plot_titles)

    scalfac = 1.0
    figwidth = 10
    figheight = 8

    if args.per_step:
        timing_names = ["time_second_10"]
        timing_labels = ["walltime per time step"]
        subplot_titles = ["Walltime per Time Step"]
        scalfac = 1.0/9.0
        figheight = 4

    numplots = len(timing_names)

    # Plot the data
    fig, ax = plt.subplots(ncols=1, nrows=numplots, sharex=True,
                           figsize=(figwidth, figheight), constrained_layout=True)

    if numplots == 1:
        ax = [ax]

    for i in range(numplots):
        ax[i].set_title(subplot_titles[i])

    leg = []
    nfiles = len(args.files)
    legend_ready = [False for _ in range(nfiles)]

    # Grab the data from the YAML timing file
    for f, datafile in enumerate(args.files):
        casename = os.path.splitext(os.path.basename(datafile))[0]
        yaml_data = yaml.load_all(open(datafile), Loader=yaml.FullLoader)
        # Remove yaml's trailing None
        raw_data = [d for d in yaml_data if d is not None]
        data = []
        for d in raw_data:
            d["run_date"] = parse_datetime(d["run_date"])
            if args.date:
                start_date = date2num(parse_datetime(args.date+" 00:00"))
                run_date = date2num(d["run_date"])
                if run_date < start_date:
                    continue

            if args.end:
                end_date = date2num(parse_datetime(args.end+" 00:00"))
                run_date = date2num(d["run_date"])
                if run_date > end_date:
                    continue

            data.append(d)

            kwargs = {
                "marker": markers[f],
                "ms": 5,
                "markerfacecolor": "w",
                "linestyle": "-",
                "linewidth": 2,
            }

            # clean data
            for s in timing_names:
                data = [d for d in data if s in d]

            for i, s in enumerate(timing_names):
                nproc = 1 if args.multicase else d["num_processors"]
                label = casename if args.multicase else f"{nproc}"
                p, = ax[i].plot([d["run_date"] for d in data],
                                [scalfac*d[s] for d in data],
                                label=label, color=colors[f], **kwargs)
                if not legend_ready[f]:
                    leg.append(p)
                    legend_ready[f] = True

            if args.zero:
                ylim = ax[i].get_ylim()
                plt.ylim(0, 1.5*ylim[1])

            if args.log_scale:
                ax[i].set_yscale("log", base=2)

            commentcounter = 0
            commentcolors = ["tab:cyan", "tab:pink", "tab:cyan", "tab:pink"]  # noqa
            for d in data:
                if "comment" in d and args.annotate:
                    commentcounter += 1
                    ytext0 = 1.2
                    ytextdelta = 0.1
                    ytext = ytext0 + (commentcounter % 4) * ytextdelta
                    # color = commentcolors[commentcounter % 4]
                    color = "tab:gray"
                    for i in range(numplots):
                        xlim = ax[0].get_xlim()
                        xt = (date2num(d["run_date"])-xlim[0]) / (xlim[1]-xlim[0])
                        # get the coordinates on the axis
                        #(xt, _) = \
                        #    ax[0].transLimits.transform((date2num(d["run_date"]),0))
                        ax[i].plot([xt, xt], [-0.05, ytext-0.05],
                                   transform=ax[i].transAxes,
                                   color=color, linestyle="--", lw=1, clip_on=False)
                        if i == 0:
                            ax[i].text(xt, ytext, d["comment"], ha="center",
                                       transform=ax[i].transAxes, color=color,
                                       rotation=90)

    ax[-1].tick_params(axis="x", labelrotation=45)
    ax[-1].set_xlabel("date")
    for i in range(numplots):
        ax[i].grid(True)

    legend_title = "MIRGE-Com Casename" if args.multicase else "Number of GPUs"
    legend_ncols = 1 if args.multicase else 4
    ax[0].legend(handles=leg,
                 title=legend_title,
                 bbox_to_anchor=(0, 1.02, 0.3, 0.2), loc="lower left",
                 mode="expand", borderaxespad=0, ncol=legend_ncols)

    if args.per_step:
        ax[0].set_ylabel("walltime/step (s)")
    else:
        for i in range(numplots):
            ax[i].set_ylabel("time (s)")

    if args.save_plot:
        plt.savefig(args.save_plot, bbox_inches="tight")
    else:
        plt.show()


if __name__ == "__main__":
    main()
