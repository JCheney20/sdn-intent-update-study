# Exploiting Temporal Vulnerabilities for Unauthorized Access in Intent-Based Networking

## Requirements
- A Linux machine (tested on Ubuntu 22.04 and NixOS 24.05)
- Docker (tested on 24.0.9)

## Artifacts
This project contains two artifacts. The first is the set of scripts that generated various networks (fat tree, cisco, and stanford), as well as run our detection algorithms (Spotlight and the naive baseline algorithm). The second artifact is a Jupyter Notebook that contains our analysis scripts.

## Running Spotlight 
The evaluations can be run using the `spotlight` script, which will build and run the Docker image and output run statistics to a CSV file of the form `timing-<YEAR>-<MONTH>-<DAY>-<TIME>.csv`, where the date and time are when the run was started. 


The docs for the command line tool are shown below.

    usage: spotlight [--log-level L | --start S | --fattree-k-max F_max | --panther-k A,B,C,...] --topo T --trials N --algorithm A
    options:
        --log-level <L>          Choose the log level: DEBUG, INFO, WARNING, or ERROR.
        --topo <T>               Choose the topology to evaluate, choices are: cisco, stanford, or fattree.
        --start <S>              The trial number to start from to resume a failed run. 
        --algorithm <A>          The detection algorithm(s) to use: choices are: baseline, panther, or all.
        --fattree-k-max <F_max>  The maximum of the non-inclusive range for k values for the fattree parameter. 
                                 This may be skipped if it is not a multiple of three greater than fattree_k_min. 
                                 Only applies if --topo is "fattree". The minimum of the range is 4.
        --trials <N>             The number of trials to run.
        --panther-k <K>          A comma-separated list of k values for the Panther algorithm. Only applies when using
                                 the Panther algorithm.

Due to some complexities in how data is exported from the container. The container will not give any indication it has completed. However, if no output is printed for 20 minutes or so, it can be considered done. The process must be executed by issuing a `docker stop <CONTAINER_NAME>`.

## Reproducing Evalutations
The commands for reproducing the results in the paper are shown below. The first runs both the Spotlight and baseline algorithms ten times on a series of fat tree topologies for a series of Panther `k` values.

``` shell
    ./spotlight --fattree-k-max 17 --panther-k 3,5,10,15,20 --topo fattree --trials 10 --algorithm all 
```

This command runs Spotlight and the baseline on the Cisco topology ten times.
``` shell
    ./spotlight --panther-k 20 --topo cisco --trials 10 --algorithm all 
```

This command runs Spotlight and the baseline on the Stanford backbone topology ten times.
``` shell
    ./spotlight --panther-k 20 --topo stanford --trials 10 --algorithm all 
```

Note that the first of the three above commands takes a long time to run, usually more than 24 hours. Additionally, due to a possible memory leak, it occasionally crashes after a few hours. In this case, the already completed results will still be written to a CSV. The run can be restarted by executing the same command and appending the `--start S` parameter, where `S-1` is the last run that appears in the already stored CSV.

A shortened version that will get approximate results can be reproduced by replacing the first command above with the following.
``` shell
    ./spotlight --fattree-k-max 17 --panther-k 3,5,10,15,20 --topo fattree --trials 1 --algorithm all 
```

## Reproducing Analysis
We provide the Jupyter Notebook used in our analysis. Cells two, three, and four contain a variable pointing to the path of a CSV file. These correspond to the outputs of above commands one, two, and three, respectively. All the cells in the notebook were used at various points during our analysis, but not all plots and numbers were included in the final version of the paper.

