---
title: "last class, miscellaneous"
---

## Compute Canada stuff

* https://hackmd.io/@bbolker/r_hpc
* job arrays, etc.: also [old school approach](https://github.com/bbolker/betararef/blob/master/inst/batchfiles/betasim_batch11gen)
* moving stuff: `rsync`, `git clone`/`pull`/`push`, `wget`/`curl`, `scp`/`sftp`
* priority

## split-apply-combine, sparklyr etc.

* map-reduce is more complicated than I thought it was:
    * **map** figures out how to distribute data to workers
	* **reduce** runs the computation/reduction steps
* [Apache Hive](https://aws.amazon.com/what-is/apache-hive/), Amazon S3

## Spark

* @luraschiMasteringSparkComplete2019
* mostly off-the-shelf standard operations (acts like `dbplyr` etc etc with a different set of operations)
* statistical, ML methods, e.g. `ml_linear_regression`: see [appendix](https://therinspark.com/appendix.html#appendix-modeling)

## bandwidth

* moving data takes a long  time
* https://what-if.xkcd.com/31/: "When - if ever - will the bandwidth of the Internet surpass that of FedEx?"
* very fast connections (see https://en.wikipedia.org/wiki/List_of_interface_bit_rates) are 10 Gbit/s ~ 1 Gbyte/s ~ 28 hours to move 100 Tb. 
* **data engineering**

## federated data analysis

* distributed data analysis, mostly for privacy/confidentiality concerns
* https://datashield.org/
* lots of non-disclosure checks
* @gayeDataSHIELD2014; @dragandsSwissKnife2020; @hauschildFederated2022

## stochastic gradient descent

* $\cal O(1)$ (!!)
* distributed?
* "distribute-once" problems

## problem types/parallelization

### easy

* simulation testing of methods
* simulation-based inference (bootstrap)
* cross-validation
* model selection

at thread/GPU/[SIMD](https://en.wikipedia.org/wiki/Single_instruction,_multiple_data) level: linear algebra (deep learning etc etc)

### harder

sequential approaches: requires multiple steps

* particle filtering/particle MCMC

## references
