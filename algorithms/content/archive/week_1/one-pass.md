# One-Pass Hash table

#### 
    The One-Pass Hash table approach processes input data in a single sequential scan (one pass).
    The Key is using an in-memory hash table (dictionary) to instantly store and look up values encountered so far. This allows operations that might normally require a second pass(like finding a complement or checking a frequency) to happen instantaneously within the same loop.
    Memorization point: Read once, use hash table to remember previous values instantly. Time complexity is highly efficient at O(N)
####

# Single Pass Optimization
The single-pass optimization algorithm approach refers to a class of algorithms that process their input data exactly once, in a single sequential traversal or "pass." This approach is particularly valuable when dealing with large datasets or streaming data where storing the entire dataset in memory is infeasible or inefficient.
Here are the key characteristics and advantages of the single-pass optimization algorithm approach:

```
Single Traversal: The core principle is that the algorithm reads and processes each element of the input data only once. It does not revisit previously processed data points.
Limited Memory Footprint: This approach typically requires a memory footprint that is independent of the total size of the input data. Instead of storing the entire dataset, it often maintains only necessary statistics, summaries, or a small buffer of recent data points. This makes it suitable for big data and streaming applications.
Efficiency for Streaming Data: When data arrives in a continuous stream, a single-pass algorithm can process it in real-time without needing to wait for the entire stream to be collected.
Examples:
Calculating mean or variance: A single pass can be used to compute the sum and sum of squares of data points, from which the mean and variance can be derived without storing all individual values.
Online learning algorithms: Many online learning methods update model parameters incrementally with each incoming data point, effectively performing a single pass over the training data.
One-pass AUC optimization: In machine learning, algorithms exist that optimize the Area Under the Curve (AUC) metric in a single pass, often by storing only first and second-order statistics of the data.
In essence, the single-pass optimization approach prioritizes efficiency in terms of both time and memory by performing computations as data becomes available, avoiding the need for multiple data scans or extensive data storage.
```