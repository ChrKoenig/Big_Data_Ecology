Computational performance
================
Christian König

**This practical exercise is a part of the workshop [Big Data
Ecology](https://github.com/ChrKoenig/Big_Data_Ecology)**

------------------------------------------------------------------------

## Introduction

This practical covers the topics of performance pitfalls, code
benchmarking and profiling, and parallel processing in `R`.

We will use the following packages:

``` r
library(bench)
library(profvis)
library(parallel)
library(foreach)
library(doParallel)
```

If you haven’t installed them, please do so with the following command:

``` r
install.packages(c("bench", "profvis", "foreach", "doParallel"))
```

## Vectorization, looping and memory allocation

In the lecture, we have learned that some design decisions underlying
the `R` language and its implementation (dynamic typing, mutable
environments, code interpretation, …) entail performance penalties
compared to other programming languages. In return, `R` provides one of
the most productive and featureful environments for data processing.
Luckily, we can avoid many of `R`’s performance bottlenecks by
structuring our code accordingly.

Let’s implement a set of functions that calculate the row sums of a
matrix. We will start with the most idiomatic and efficient solution and
make it gradually ‘worse’ by replacing built-in functions with
self-written ones, adding loops, and modifying/growing objects in each
iteration.

``` r
# Vectorized, fully optimized
f1 = function(x){
  rowSums(x)
}

# Vectorized, partially optimized (sum function)
f2 = function(x){
  apply(big_matrix, 1, sum)     # Apply sum function over rows of x
}

# Partially vectorized, not optimized
f3 = function(x){
  result = apply(x, 1, function(r){     # Apply custom function over rows of x
    sum_r = 0                           # sum of current row = 0
    for(i in 1:length(r)){              # loop over columns of current row
      sum_r = sum_r + r[i]              # add each element to sum_r
    }
    return(sum_r)                       # return sum of current row
  })
  return(result)
}

# Not vectorized, not optimized, memory pre-allocation
f4 = function(x){
  result = vector(mode = "integer", length = nrow(x))   # pre-allocate result vector
  for(i in 1:nrow(x)){            # Loop over rows of x
    sum_r = 0                     # sum of current row = 0
    for(j in 1:ncol(x)){          # loop over columns of current row
      sum_r = sum_r + x[i,j]      # add each element to sum_r
    }
    result[i] = sum_r             # Write sum of current row into result vector
  }
  return(result)
}

# Not vectorized, not optimized, no memory pre-allocation
f5 = function(x){
  result = c()                    # define empty result vector
  for(i in 1:nrow(x)){            # Loop over rows of x
    sum_r = 0                     # sum of current row = 0
    for(j in 1:ncol(x)){          # loop over columns of current row
      sum_r = sum_r + x[i,j]      # add each element to sum_r 
    }
    result = c(result, sum_r)     # Append sum of current row to result vector
  }
  return(result)
}
```

First of all, pay attention to the differences in clarity and
conciseness: Going from `f1` to `f5`, the implementations become
increasingly complex and difficult to read. The reason is that `base`
functions such as `rowSums()` and `sum()` hide the algorithmic
complexity from us but use highly optimized `C` code under the hood.

We use the `bench` package to compare our five function implementations
with respect to speed and memory use. To this end, we create a matrix
and feed it to each of the functions using the `bench::mark()` function.
The function evaluates each expression for a given amount of time (or
iterations) and returns a `tibble` with performance metrics. For easier
comparison, we set the option `relative = T`.

``` r
big_matrix = matrix(1:1000000, ncol = 1000, nrow = 1000) # 1000x1000 matrix
bench::mark(
  f1(big_matrix),
  f2(big_matrix),
  f3(big_matrix),
  f4(big_matrix),
  f5(big_matrix),
  relative = T
)
```

    ## # A tibble: 5 x 6
    ##   expression       min median `itr/sec` mem_alloc `gc/sec`
    ##   <bch:expr>     <dbl>  <dbl>     <dbl>     <dbl>    <dbl>
    ## 1 f1(big_matrix)  1      1        25.6        1        NaN
    ## 2 f2(big_matrix)  3.36   4.43      4.98     372.       Inf
    ## 3 f3(big_matrix) 18.1   27.1       1.03     505.       Inf
    ## 4 f4(big_matrix) 19.5   19.4       1.21      10.8      NaN
    ## 5 f5(big_matrix) 19.9   20.3       1        126.       Inf

As we suspected, the performance difference between the implementations
is substantial, with `f1` being \~17-times faster and \~500-times more
memory-efficient than the respective worst-performing implementation. We
conclude that, as a rule of thumb, the more we ‘outsource’ actual
computations to `R`, the more complicated, error-prone and slow our
code.

## Profiling

Obviously, there is no optimized `base` function for everything and we
often need to write our own functions to accomplish a given task. The
code for such custom functions may become quite long and benchmarking
the entire function is not very helpful when trying to identify
performance bottlenecks. In such cases, we can use a profiling tool that
analyses our code line by line. In `R`, this can be achieved with
`profvis` package.

One curious detail of our previous benchmark was the fact that the most
memory-intensive implementation was not `f5`, but `f3`. Lets profile
`f3` with `profvis::profvis()`

``` r
# Profvis profile of f3
profvis({
  x = matrix(1:10000000, ncol = 10000, nrow = 1000) 
  result = apply(x, 1, function(r){     # Apply custom function over rows of x
    sum_r = 0                           # sum of current row = 0
    for(i in 1:length(r)){              # loop over columns of current row
      sum_r = sum_r + r[i]              # add each element to sum_r
    }
    return(sum_r)                       # return sum of current row
  })
})
```

![flame graph](profvis_flamegraph.png)

The ‘Flame graph’ profile shows the time spent and memory used for each
line of the code. Interestingly, the `apply` function took 110 ms and
7.1 MB of memory in total, while the `for` loop and summation within the
applied function only took a total of 50 ms and 4.4 MB. Unfortunately,
though, `profvis` has no insights into some internal functions and
functions written in languages other than `R`.

We can click the ‘Data’ tab to get slightly more information and a
hierachical tree view of the profile.

![data](profvis_data.png)

Here, we see that a call to `aperm.default` has taken 30 ms of the total
110 ms of our `apply` expression. This additional time spent on setting
up rather than performing the computations is called **overhead** and is
an inevitable part of programming. However, some solutions have a larger
overhead than others. The high memory use by `f3`, for example, is
likely the result of `apply` copying each row of `big_matrix` into a new
object before feeding it to the anonymous function. In contrast, `f5`
does not make a copy of each row and, therefore, is \~4-times more
memory efficient (albeit not faster) than `f3`.

## Parallel processing

### Parallel apply functions

Now let’s move to something arguably more exciting than code profiling!
Instead of squeezing the last bit of performance from our existing code,
we simply distribute the computations across multiple CPU cores.
Theoretically, this would improve our runtime by the same factor as the
number of CPUs used, although in reality the performance gain will
always be smaller than that.

We’ve seen in the lecture that we need register a parallel backend to
set up our CPUs for parallel computation. In `R`, the default tool for
this is the `parallel` package. Per default, `parallel` sets up a
parallel socket cluster, which is fine for our purposes.

``` r
n_cpus = parallel::detectCores()     # Check you many CPUs are available on your system
cl = parallel::makeCluster(n_cpus)   # Create cluster
cl                                   # Print cluster properties
```

    ## socket cluster with 8 nodes on host 'localhost'

The `parallel` package also provides us with a set of [parallelized
functions](https://stat.ethz.ch/R-manual/R-patched/library/parallel/html/clusterApply.html)
that correspond to the apply-family functions in `base` R. With the
socket cluster set up, we can now benchmark these functions against each
other.

First, we define a function `sleep` that takes an argument `x` and
suspends the execution of `R` for `x` seconds. Second, we define a
`sleep_times` vector holding some low single digit values. Finally, we
use `sapply()` and `parSapply()` to apply our `sleep` function to each
element of `sleep_times`. Take a moment and think about what runtimes
you would expect for the sequential and parallel implementation.

``` r
sleep = function(x){Sys.sleep(x)}
sleep_times = c(1,3,2,1)
bench::mark(
  sapply(sleep_times, sleep),
  parSapply(cl, sleep_times, sleep),
  memory = F  # We need to turn off memory profiling for parallel computations
)
```

    ## # A tibble: 2 x 6
    ##   expression                            min  median `itr/sec` mem_alloc `gc/sec`
    ##   <bch:expr>                        <bch:t> <bch:t>     <dbl> <bch:byt>    <dbl>
    ## 1 sapply(sleep_times, sleep)          7.01s   7.01s     0.143        NA        0
    ## 2 parSapply(cl, sleep_times, sleep)      3s      3s     0.333        NA        0

Was your intuition right? The sequential version took `sum(sleep_times)`
seconds, whereas the parallel version took `max(sleep_times)` seconds.
This makes sense because `sapply` processes the next element of a vector
or list only when the the current element is finished (*sequential*). On
the other hand, `parSapply` distributes the elements of across our
cluster and applies the `sleep` function separately (*parallel*), thus
taking only as much time as the slowest task (note that this only
applies if there are at least as many CPUs as elements in
`sleep_times`).

### Parallel for loops

Another option for parallel processing in `R` is the parallel `for` loop
provided by the `foreach` package. For this, we need to register a
parallel backend with the `doParallel` package before we can start our
computations.

``` r
doParallel::registerDoParallel(cores=detectCores())    # Create cluster for %dopar% function
bench::mark(
  foreach(i = 1:length(sleep_times)) %dopar% sleep(sleep_times[i]),
  memory = F    # We need to turn off memory profiling for parallel computations
)
```

    ## # A tibble: 1 x 6
    ##   expression                                                          min median
    ##   <bch:expr>                                                       <bch:> <bch:>
    ## 1 foreach(i = 1:length(sleep_times)) %dopar% sleep(sleep_times[i])  3.03s  3.03s
    ## # … with 3 more variables: itr/sec <dbl>, mem_alloc <bch:byt>, gc/sec <dbl>

Just like the `parSapply` version, the parallel `foreach` version takes
approximately `max(sleep_times)` seconds.

Sometimes, a `for` loop gives you a bit more flexibility than an
encapsulated `apply` function. Moreover, with the `foreach` package you
can define how your results should be put back together using the
`.combine` argument. For example, you could use
`foreach(1:100, .combine = cbind) %dopar% ...` if your results are
vectors of the same size and you want to `cbind` them to a dataframe.

## Exercise

-   Define a new function, `f3_par`, and replace the `apply` with its
    parallel counterpart from the `parallel` package
-   Define a new function, `f5_par`, and replace the outer `for` loop
    with its parallel counterpart from the `foreach` package
-   Use the `bench` package to benchmark your parallelized functions
    against each other and their sequential versions. How did the
    performance change?

## Some final notes

Performance considerations become increasingly relevant when working
with big data sets, automated processing pipelines, and complex
algorithms. Thus, knowing whether – and which part of – your code
performs poorly and how to improve it is a great tool to have in your
toolbox. If the solutions provided here are not enough for your task,
there is still room for more! For example, you can write your own `C++`
functions and easily integrate them into your `R` workflow with the
`Rcpp` package. Or you can run parallel computations not just on your
local machine but on a [high-performance compute
cluster](https://www.uni-potsdam.de/de/zim/angebote-loesungen/hpc) and
benefit from dozens or hundreds of CPUs. Packages like `rslurm` can help
you with that, too.
