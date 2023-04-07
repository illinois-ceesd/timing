#!/usr/bin/env python3
"""Plot MIRGE-Com timing results."""
import argparse
import yaml
from matplotlib.dates import date2num
import matplotlib.pyplot as plt
import numpy as np

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

def adjust_lightness(color, amount=0.5):
    """
    https://stackoverflow.com/questions/37765197/darken-or-lighten-a-color-in-matplotlib

    Lightens the given color by multiplying (1-luminosity) by the given amount.
    Input can be matplotlib color string, hex string, or RGB tuple.

    Examples:
    >> lighten_color('g', 0.3)
    >> lighten_color('#F034A3', 0.6)
    >> lighten_color((.3,.55,.1), 0.5)
    """
    import matplotlib.colors as mc
    import colorsys
    try:
        c = mc.cnames[color]
    except:
        c = color
    c = colorsys.rgb_to_hls(*mc.to_rgb(c))
    return colorsys.hls_to_rgb(c[0], max(0, min(1, amount * c[1])), c[2])


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
    parser.add_argument("-d", "--date", metavar="YYYY-MM-DD")
    parser.add_argument("-e", "--end", metavar="YYYY-MM-DD")
    parser.add_argument("--save-plot", metavar="NAME.{pdf,png}")
    args = parser.parse_args()

    markers = ["o", "s", "v", "^", ">", "<", "D", "P", "*", "X"]

    timing_names = ["time_startup", "time_first_step", "time_second_10"]
    timing_labels = ["startup", "first timestep", "second 9 timesteps"]
    subplot_titles = ["Startup", "First timestep", "Second 9 Timesteps"]
    plotid = 2

    scalfac = 1.0
    figwidth = 10
    figheight = 3

    fig, ax = plt.subplots(figsize=(figwidth, figheight), constrained_layout=True)

    ax.set_title(subplot_titles[plotid])

    files = [#'./y3-prediction/yaml/prediction-scalability_np1-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np2-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np4-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np8-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np16-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np32-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np64-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np128-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np256-timing-data.yaml',
             './y3-prediction/yaml/prediction-scalability_np512-timing-data.yaml']

    nfiles = len(files)

    # Grab the data from the YAML timing file
    for f, datafile in enumerate(files):
        yaml_data = yaml.load_all(open(datafile), Loader=yaml.FullLoader)

        # Remove yaml's trailing None
        raw_data = [d for d in yaml_data if d is not None]
        # Remove empty data
        raw_data = [d for d in raw_data if d['time_second_10'] is not None]

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
            "marker": '', #markers[f],
            "ms": 5,
            "markerfacecolor": "w",
            "linestyle": "-",
        }

        nproc = d["num_processors"]
        label = f"{nproc}"

        #print(datafile, f)
        #colorscale = np.flip(np.linspace(0.8, 1.8, len(files)))
        #color = adjust_lightness('tab:blue', colorscale[f])
        colors = plt.cm.spring_r(np.linspace(0,1,len(files)))
        color = colors[f]
        lws = np.linspace(0.8, 3, len(files))
        lw = lws[f]
        p, = ax.plot([d["run_date"] for d in data],
                     [scalfac*d[timing_names[plotid]] for d in data],
                     label=label, color=color, lw=lw, **kwargs)

    ax.tick_params(axis="x", labelrotation=45)
    ax.set_xlabel("date")
    ax.grid(True)

    ax.legend(title="Number of GPUs",
              bbox_to_anchor=(0, 1.02, 0.3, 0.2), loc="lower left",
              mode="expand", borderaxespad=0, ncol=3, frameon=False)

    ax.set_ylabel("time (s)")

    if args.save_plot:
        plt.savefig(args.save_plot, bbox_inches="tight")
    else:
        plt.show()


if __name__ == "__main__":
    main()
