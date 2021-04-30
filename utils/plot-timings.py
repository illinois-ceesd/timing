#! /usr/bin/env python3
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
    
    # Grab the data from the YAML timing file
    data = yaml.load_all(open("y1-nozzle-timings.yaml", "r"), Loader=yaml.FullLoader)
    data = [d for d in data if d is not None]  # Remove yaml's trailing None
    for d in data:
        d["run_date"] = parse_datetime(d["run_date"])

    # Plot the data
    plt.figure(figsize=(10, 5))
    kwargs = {
        "marker": "o",
        "ms": 5,
        "markerfacecolor": "w",
        "linestyle": "-",
        "linewidth": 2,
    }

    timing_names = ["time_startup", "time_first_step", "time_second_10"]
    for s in timing_names:
        plt.plot(
                [d["run_date"] for d in data],
                [d.get(s, None) for d in data],
                label=s.replace("time_", ""), **kwargs)

    for irow, d in enumerate(data):
        if "comment" in d:
            top = max(d.get(tname, 0) for tname in timing_names) * 1.1
            plt.gca().annotate(d["comment"],
                    xy=(d["run_date"], top),
                    xytext=(d["run_date"], top+20),
                    ha="center",
                    arrowprops=dict(arrowstyle="->", connectionstyle="arc3"),
                    )

    plt.gca().tick_params(axis="x", labelrotation=45, labelsize=16)
    plt.gca().grid(True)
    plt.gca().set_xlabel("date", fontsize=20)
    plt.gca().set_ylabel("time (s)", fontsize=20)
    plt.gca().legend(loc="best")
    plt.savefig("y1-nozzle-timings.png", bbox_inches="tight")

    plt.show()


if __name__ == "__main__":
    main()
